import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delicious/main.dart';
import 'package:delicious/recipe_import.dart';

String page({String name = 'Lemon pasta'}) =>
    '''
<script type="application/ld+json">broken json</script>
<script type="application/ld+json">${jsonEncode({
      '@graph': [
        {'@type': 'WebPage'},
        {
          '@type': ['Recipe'],
          'name': name,
          'totalTime': 'PT1H15M',
          'recipeIngredient': ['200g pasta', '1 lemon &amp; zest'],
          'recipeInstructions': [
            {
              '@type': 'HowToSection',
              'itemListElement': [
                {'@type': 'HowToStep', 'text': '<p>Boil the pasta.</p>'},
                {'@type': 'HowToStep', 'text': 'Add lemon.'},
              ],
            },
          ],
        },
      ],
    })}</script>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dish image falls back to social metadata and lazy recipe photos', () {
    final url = Uri.parse('https://example.com/pasta');
    for (final metadata in [
      '<meta property="og:image" content="/dish.jpg">',
      '<meta name="twitter:image" content="/dish.jpg">',
      '<div class="wprm-recipe-image"><img src="data:image/gif;base64,AA" data-lazy-src="/dish.jpg"></div>',
      '<img itemprop="image" srcset="/dish.jpg 800w">',
    ]) {
      expect(
        parseRecipeHtml('$metadata${page()}', url).image,
        'https://example.com/dish.jpg',
      );
    }
  });

  test('dish image resolves a referenced ImageObject', () {
    final source =
        '<script type="application/ld+json">${jsonEncode({
          '@graph': [
            {'@type': 'ImageObject', '@id': '#photo', 'url': '/dish.jpg'},
            {
              '@type': 'Recipe',
              'name': 'Soup',
              'image': {'@id': '#photo'},
              'recipeIngredient': ['Water'],
              'recipeInstructions': ['Boil.'],
            },
          ],
        })}</script>';
    expect(
      parseRecipeHtml(source, Uri.parse('https://example.com/soup')).image,
      'https://example.com/dish.jpg',
    );
  });

  test(
    're-import refreshes an old recipe image without creating a duplicate',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RecipeStore([], prefs);
      final url = Uri.parse('https://example.com/pasta');
      await store.addImported(parseRecipeHtml(page(), url));
      final refreshed = await store.addImported(
        parseRecipeHtml(
          '<meta property="og:image" content="/dish.jpg">${page()}',
          url,
        ),
      );
      expect(refreshed.image, 'https://example.com/dish.jpg');
      expect(store.recipes, hasLength(1));
      expect(RecipeStore([], prefs).recipes.single.image, refreshed.image);
    },
  );
  test(
    'step photos resolve relative URLs, HTML anchors and survive storage',
    () {
      final recipe = parseRecipeHtml('''
      <div id="step-two"><img data-src="/second.jpg"></div>
      <script type="application/ld+json">${jsonEncode({
        '@type': 'Recipe',
        'name': 'Soup',
        'image': ['/cover.jpg'],
        'recipeIngredient': ['Water'],
        'recipeInstructions': [
          {
            'text': 'Heat water.',
            'image': {'contentUrl': '../first.jpg'},
          },
          {'text': 'Stir.', 'url': '#step-two'},
          {'text': 'Serve.', 'image': 'javascript:bad'},
        ],
      })}</script>
    ''', Uri.parse('https://example.com/recipes/soup'));
      final restored = Recipe.fromJson(jsonDecode(jsonEncode(recipe.toJson())));
      expect(restored.stepImages, [
        'https://example.com/first.jpg',
        'https://example.com/second.jpg',
        '',
      ]);
      expect(restored.imageForStep(2), isEmpty);
      expect(restored.steps, ['Heat water.', 'Stir.', 'Serve.']);
    },
  );
  test('extracts graph recipe, sections, entities, duration, and source', () {
    final recipe = parseRecipeHtml(
      page(),
      Uri.parse('https://example.com/pasta#recipe'),
    );
    expect(recipe.name, 'Lemon pasta');
    expect(recipe.time, 75);
    expect(recipe.ingredients[1][1], '1 lemon & zest');
    expect(recipe.steps, ['Boil the pasta.', 'Add lemon.']);
    expect(recipe.sourceUrl, 'https://example.com/pasta');
    expect(recipe.rating, isEmpty);
  });
  test('rejects invalid URLs and missing recipe data', () async {
    for (final url in [
      'hello',
      'file:///tmp/a',
      'https://',
      'https://user:pass@example.com',
    ]) {
      expect(
        () => RecipeImporter.validateUrl(url),
        throwsA(isA<RecipeImportException>()),
      );
    }
    expect(
      () => parseRecipeHtml(
        '<h1>No recipe</h1>',
        Uri.parse('https://example.com'),
      ),
      throwsA(isA<RecipeImportException>()),
    );
    final importer = RecipeImporter(
      clientFactory: () =>
          MockClient((_) async => http.Response('Denied', 403)),
    );
    await expectLater(
      importer.importUrl('https://example.com'),
      throwsA(isA<RecipeImportException>()),
    );
  });
  test(
    'imports persist and concurrent duplicate saves are deduplicated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RecipeStore(await loadRecipes(), prefs);
      final recipe = parseRecipeHtml(
        page(),
        Uri.parse('https://example.com/pasta'),
      );
      await Future.wait([store.addImported(recipe), store.addImported(recipe)]);
      final restored = RecipeStore(await loadRecipes(), prefs);
      expect(restored.recipes.where((r) => r.sourceUrl != null), hasLength(1));
      expect(restored.recipes.last.steps, recipe.steps);
      expect(store.recipes.length, restored.recipes.length);
    },
  );
  testWidgets('mobile import validates, previews, saves and opens details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final recipes = await tester.runAsync(loadRecipes);
    final prefs = await SharedPreferences.getInstance();
    final store = RecipeStore(
      recipes!,
      prefs,
      importer: RecipeImporter(
        clientFactory: () =>
            MockClient((_) async => http.Response(page(), 200)),
      ),
    );
    await tester.pumpWidget(DeliciousApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Import recipe'));
    await tester.tap(find.text('Import recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Import recipe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a complete'), findsOneWidget);
    String clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': clipboardText} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Paste link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clipboard is empty'), findsOneWidget);
    clipboardText = ' https://example.com/pasta ';
    await tester.tap(find.text('Paste link'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('import-url')))
          .controller!
          .text,
      'https://example.com/pasta',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Review recipe'), findsOneWidget);
    expect(store.recipes.any((r) => r.sourceUrl != null), isFalse);
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetails), findsOneWidget);
    expect(find.text('Lemon pasta'), findsOneWidget);
    expect(store.recipes.last.sourceUrl, 'https://example.com/pasta');
    expect(tester.takeException(), isNull);
  });
}

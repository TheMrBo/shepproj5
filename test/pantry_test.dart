import 'package:delicious/pantry_match.dart';
import 'package:delicious/pantry_screen.dart';
import 'package:delicious/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recipe recipe(String name, List<String> ingredients) => Recipe(
  id: name,
  name: name,
  category: 'Breakfast',
  image: '',
  ingredientItems: ingredients
      .map((name) => IngredientItem(quantity: '', unit: '', name: name))
      .toList(),
);

void main() {
  test('matches plurals and preparation but preserves ingredient types', () {
    final matches = matchPantryRecipes(
      [
        recipe('Soup', ['Fresh tomatoes, diced', 'Onion', 'Coconut milk']),
        recipe('Eggs', ['Egg', 'Egg']),
        recipe('No ingredients', []),
        recipe('Butter', ['Butter']),
      ],
      ['tomato', 'onions', 'milk', 'eggs'],
    );
    expect(matches.map((m) => m.recipe.name), ['Eggs', 'Soup']);
    expect(matches.first.available, ['Egg']);
    expect(matches.first.missing, isEmpty);
    expect(matches.last.missing, ['Coconut milk']);
    expect(
      matchPantryRecipes([
        recipe('Egg', ['Egg']),
      ], []),
      isEmpty,
    );
  });

  testWidgets(
    'pantry persists, filters matches, removes ingredients and opens recipe',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final recipes = [
        recipe('Egg dish', ['Egg']),
        recipe('Pancakes', ['Egg', 'Flour']),
      ];
      Recipe? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.of(context).push<Recipe>(
                    MaterialPageRoute(
                      builder: (_) => PantryScreen(
                        recipes: recipes,
                        preferences: preferences,
                      ),
                    ),
                  );
                },
                child: const Text('Open pantry'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open pantry'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pantry-input')),
        'eggs, Egg',
      );
      await tester.tap(find.text('Add ingredients'));
      await tester.pumpAndSettle();
      expect(preferences.getStringList('pantry_ingredients'), ['eggs']);
      expect(find.text('Missing: Flour'), findsOneWidget);
      await tester.tap(find.text('All ingredients available'));
      await tester.pumpAndSettle();
      expect(find.text('Pancakes'), findsNothing);
      await tester.tap(find.text('View recipe'));
      await tester.pumpAndSettle();
      expect(selected?.name, 'Egg dish');
      await tester.tap(find.text('Open pantry'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'eggs'), findsOneWidget);
      final chip = tester.widget<InputChip>(find.byType(InputChip));
      chip.onDeleted!();
      await tester.pumpAndSettle();
      expect(preferences.getStringList('pantry_ingredients'), isEmpty);
      expect(
        find.text(
          'Add a few ingredients to find recipes from your collection.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Discover exposes pantry on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = RecipeStore([], await SharedPreferences.getInstance());
    await tester.pumpWidget(DeliciousApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cook with what I have'));
    await tester.pumpAndSettle();
    expect(find.byType(PantryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

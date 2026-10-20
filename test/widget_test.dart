import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delicious/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = RecipeStore(
      await loadRecipes(),
      await SharedPreferences.getInstance(),
    );
  });
  test(
    'favorites survive store recreation, including an empty collection',
    () async {
      await store.toggle('ramen');
      await store.toggle('salad');
      final restored = RecipeStore(
        store.recipes,
        await SharedPreferences.getInstance(),
      );
      expect(restored.saved, isEmpty);
      await restored.toggle('pancakes');
      expect(RecipeStore(store.recipes, restored.preferences).saved, {
        'pancakes',
      });
    },
  );
  testWidgets('mobile search, saved navigation, and recipe route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DeliciousApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.enterText(find.byKey(const Key('recipe-search')), 'pancakes');
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsOneWidget);
    await tester.ensureVisible(find.text('Pancakes'));
    await tester.tap(find.text('Pancakes'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetails), findsOneWidget);
    await tester.tap(find.byTooltip('Save Pancakes'));
    await tester.pumpAndSettle();
    expect(store.saved.contains('pancakes'), isTrue);
    await tester.tap(find.byTooltip('Back to recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Your saved recipes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop category filter and detail dialog', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DeliciousApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsNWidgets(2));
    await tester.tap(find.text('Pancakes'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Recipe'));
    await tester.pumpAndSettle();
    expect(find.text(store.recipes[1].steps[0]), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:delicious/recipe.dart';
import 'package:delicious/recipe_import.dart';

void main() {
  test(
    'full instructions exclude summaries and promotions; photos follow text, not order',
    () {
      final source =
          '''
      <img src="/advertisement.jpg">
      <h2>How to make soup</h2>
      <figure><img src="/sauce.jpg"></figure>
      <ol><li>Mix soy sauce ingredients in a bowl.</li></ol>
      <figure><img src="/beef.jpg"></figure>
      <ol><li>Brown ground beef with onion and garlic.</li></ol>
      <h2>Related recipes</h2>
      <figure><img src="/unrelated.jpg"></figure>
      <ol><li>Serve soup in bowls.</li></ol>
      <script type="application/ld+json">${jsonEncode({
            '@type': 'Recipe',
            'name': 'Soup',
            'image': '/dish.jpg',
            'description': 'Subscribe to my channel! Here is my life story.',
            'recipeIngredient': ['Beef', 'Soy sauce'],
            'recipeInstructions': [
              {'text': 'Please do not make this recipe. It is under review.'},
              {
                'name': 'ABBREVIATED RECIPE',
                'itemListElement': [
                  {'text': 'Mix and cook everything.'},
                ],
              },
              {
                'name': 'FULL RECIPE',
                'itemListElement': [
                  {'text': 'Brown ground beef with onion and garlic.'},
                  {'text': '<p>Mix soy sauce ingredients in a bowl.</p><style>subscribe()</style>'},
                  {'text': 'Subscribe to my newsletter.'},
                  {'text': 'Serve soup in bowls.'},
                ],
              },
            ],
          })}</script>
    ''';
      final recipe = parseRecipeHtml(
        source,
        Uri.parse('https://example.com/soup'),
      );
      expect(recipe.steps, [
        'Brown ground beef with onion and garlic.',
        'Mix soy sauce ingredients in a bowl.',
        'Serve soup in bowls.',
      ]);
      expect(recipe.stepImages, [
        'https://example.com/beef.jpg',
        'https://example.com/sauce.jpg',
        '',
      ]);
      expect(recipe.description, isEmpty);
      expect(recipe.imageForStep(2), isEmpty);
      expect(recipe.notices.single, contains('do not make'));
      expect(Recipe.fromJson(recipe.toJson()).notices, recipe.notices);
    },
  );
}

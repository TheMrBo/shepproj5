import 'recipe.dart';

/// Conservative name matching: preparation words are ignored, but ingredient
/// types (for example coconut milk versus milk) remain distinct.
String pantryIngredientKey(String value) {
  final words = value
      .toLowerCase()
      .split(RegExp(r'[,\(]'))
      .first
      .replaceAll(RegExp(r'[^a-z\s-]'), ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'));
  const preparation = {
    'fresh',
    'chopped',
    'diced',
    'sliced',
    'minced',
    'peeled',
    'grated',
    'finely',
    'roughly',
  };
  const plurals = {
    'tomatoes': 'tomato',
    'potatoes': 'potato',
    'leaves': 'leaf',
    'berries': 'berry',
  };
  return words
      .where((word) => word.isNotEmpty && !preparation.contains(word))
      .map(
        (word) =>
            plurals[word] ??
            (word.length > 3 &&
                    word.endsWith('s') &&
                    !word.endsWith('ss') &&
                    !word.endsWith('us')
                ? word.substring(0, word.length - 1)
                : word),
      )
      .join(' ');
}

class PantryMatch {
  final Recipe recipe;
  final List<String> available;
  final List<String> missing;
  const PantryMatch(this.recipe, this.available, this.missing);
  double get coverage => available.length / (available.length + missing.length);
}

List<PantryMatch> matchPantryRecipes(
  List<Recipe> recipes,
  Iterable<String> pantry,
) {
  final keys = pantry
      .map(pantryIngredientKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  final results = <PantryMatch>[];
  for (final recipe in recipes) {
    final ingredients = <String, String>{};
    for (final item in recipe.ingredientItems) {
      final key = pantryIngredientKey(item.name);
      if (key.isNotEmpty) ingredients.putIfAbsent(key, () => item.name);
    }
    final available = <String>[];
    final missing = <String>[];
    for (final entry in ingredients.entries) {
      (keys.contains(entry.key) ? available : missing).add(entry.value);
    }
    if (available.isNotEmpty) {
      results.add(PantryMatch(recipe, available, missing));
    }
  }
  results.sort((a, b) {
    final coverage = b.coverage.compareTo(a.coverage);
    if (coverage != 0) return coverage;
    final missing = a.missing.length.compareTo(b.missing.length);
    return missing != 0 ? missing : a.recipe.name.compareTo(b.recipe.name);
  });
  return results;
}

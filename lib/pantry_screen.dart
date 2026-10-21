import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe.dart';
import 'pantry_match.dart';

class PantryScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final SharedPreferences preferences;
  const PantryScreen({
    super.key,
    required this.recipes,
    required this.preferences,
  });

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final controller = TextEditingController();
  late final List<String> pantry = List.of(
    widget.preferences.getStringList('pantry_ingredients') ?? <String>[],
  );
  bool onlyComplete = false;
  Future<void> pendingSave = Future.value();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void persist() {
    final snapshot = List<String>.of(pantry);
    pendingSave = pendingSave
        .then((_) async {
          if (!await widget.preferences.setStringList(
            'pantry_ingredients',
            snapshot,
          )) {
            throw StateError('Could not save pantry');
          }
        })
        .catchError((Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not save your pantry. Try changing an ingredient again.',
                ),
              ),
            );
          }
        });
  }

  void addIngredients() {
    final keys = pantry.map(pantryIngredientKey).toSet();
    setState(() {
      for (final value in controller.text.split(RegExp(r'[,;\n]'))) {
        final name = value.trim();
        final key = pantryIngredientKey(name);
        if (key.isNotEmpty && keys.add(key)) pantry.add(name);
      }
      controller.clear();
    });
    persist();
  }

  @override
  Widget build(BuildContext context) {
    final matches = matchPantryRecipes(
      widget.recipes,
      pantry,
    ).where((match) => !onlyComplete || match.missing.isEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Cook with what I have')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'What’s in your kitchen?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Add ingredient names separated by commas. Your pantry is saved on this device.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('pantry-input'),
                controller: controller,
                onSubmitted: (_) => addIngredients(),
                decoration: const InputDecoration(
                  labelText: 'Ingredients you have',
                  hintText: 'Eggs, flour, milk',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: addIngredients,
                  icon: const Icon(Icons.add),
                  label: const Text('Add ingredients'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pantry
                    .map(
                      (name) => InputChip(
                        label: Text(name),
                        onDeleted: () {
                          setState(() => pantry.remove(name));
                          persist();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              FilterChip(
                label: const Text('All ingredients available'),
                selected: onlyComplete,
                onSelected: (value) => setState(() => onlyComplete = value),
              ),
              const SizedBox(height: 12),
              const Text(
                'Matches use listed ingredient names, not quantities. Check the full recipe for amounts and any ingredients mentioned only in the instructions.',
              ),
              const SizedBox(height: 20),
              if (pantry.isEmpty)
                const Text(
                  'Add a few ingredients to find recipes from your collection.',
                )
              else if (matches.isEmpty)
                Text(
                  onlyComplete
                      ? 'No complete matches yet. Turn off the filter to see recipes with missing ingredients.'
                      : 'No matches yet. Try adding more ingredients or using a more specific ingredient name.',
                )
              else ...[
                Text(
                  '${matches.length} matching recipes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final match in matches)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.recipe.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match.missing.isEmpty
                                ? 'You have all listed ingredients'
                                : '${match.available.length} of ${match.available.length + match.missing.length} ingredients available',
                          ),
                          const SizedBox(height: 8),
                          Text('You have: ${match.available.join(', ')}'),
                          if (match.missing.isNotEmpty)
                            Text('Missing: ${match.missing.join(', ')}'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(match.recipe),
                            child: const Text('View recipe'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

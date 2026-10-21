import 'dart:convert';
import 'recipe.dart';
import 'recipe_import.dart';
import 'import_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'recipe.dart';

const coral = Color(0xFFEC4E6E);
const paper = Color(0xFFFAF9FB);
const muted = Color(0xFF887E8D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final recipes = await loadRecipes();
  final preferences = await SharedPreferences.getInstance();
  runApp(DeliciousApp(store: RecipeStore(recipes, preferences)));
}

Future<List<Recipe>> loadRecipes() async {
  final data =
      jsonDecode(await rootBundle.loadString('assets/recipes.json')) as List;
  return data
      .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
      .toList();
}

class RecipeStore extends ChangeNotifier {
  final List<Recipe> recipes;
  final SharedPreferences preferences;
  late final Set<String> saved =
      (preferences.getStringList('saved_recipes') ?? ['ramen', 'salad'])
          .toSet();
  late final Set<String> deletedIds =
      (preferences.getStringList('deleted_recipes') ?? <String>[]).toSet();
  Future<void> _pendingSave = Future.value();
  final RecipeImporter importer;
  RecipeStore(
    List<Recipe> initialRecipes,
    this.preferences, {
    RecipeImporter? importer,
  }) : recipes = List.of(initialRecipes),
       importer = importer ?? RecipeImporter() {
    recipes.removeWhere((r) => deletedIds.contains(r.id));
    for (final encoded
        in preferences.getStringList('imported_recipes') ?? <String>[]) {
      try {
        final recipe = Recipe.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        if (recipe.sourceUrl != null &&
            !deletedIds.contains(recipe.id) &&
            !recipes.any((r) => r.id == recipe.id)) {
          recipes.add(recipe);
        }
      } catch (_) {
        /* Skip damaged entries without losing the rest of the library. */
      }
    }
    for (final encoded
        in preferences.getStringList('community_recipes') ?? <String>[]) {
      try {
        final recipe = Recipe.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        if (!deletedIds.contains(recipe.id) &&
            !recipes.any((r) => r.id == recipe.id)) {
          recipes.add(recipe);
        }
      } catch (_) {
        /* Skip damaged entries */
      }
    }
  }

  Future<Recipe> addImported(Recipe recipe) async {
    late Recipe result;
    final operation = _pendingSave.catchError((Object _) {}).then((_) async {
      final index = recipes.indexWhere((r) => r.sourceUrl == recipe.sourceUrl);
      final imports = [
        ...recipes.where(
          (r) => r.sourceUrl != null && r.sourceUrl != recipe.sourceUrl,
        ),
        recipe,
      ];
      if (!await preferences.setStringList(
        'imported_recipes',
        imports.map((r) => jsonEncode(r.toJson())).toList(),
      )) {
        throw StateError('Could not save the imported recipe.');
      }
      if (index < 0) {
        recipes.add(recipe);
      } else {
        recipes[index] = recipe;
      }
      result = recipe;
      notifyListeners();
    });
    _pendingSave = operation;
    await operation;
    return result;
  }

  Future<Recipe> addCommunityRecipe(Recipe recipe) async {
    recipes.add(recipe);
    notifyListeners();
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final communityList = recipes
          .where((r) => r.isCommunity)
          .map((r) => jsonEncode(r.toJson()))
          .toList();
      await preferences.setStringList('community_recipes', communityList);
    });
    await _pendingSave;
    return recipe;
  }

  Future<void> rateRecipe(String recipeId, double ratingValue) async {
    final index = recipes.indexWhere((r) => r.id == recipeId);
    if (index >= 0) {
      final current = recipes[index];
      final newCount = current.ratingCount + 1;
      final newSum = current.ratingSum + ratingValue;
      final newAvg = (newSum / newCount).toStringAsFixed(1);

      final updated = current.copyWith(
        rating: newAvg,
        ratingCount: newCount,
        ratingSum: newSum,
      );
      recipes[index] = updated;
      notifyListeners();

      _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
        final communityList = recipes
            .where((r) => r.isCommunity)
            .map((r) => jsonEncode(r.toJson()))
            .toList();
        await preferences.setStringList('community_recipes', communityList);
      });
      await _pendingSave;
    }
  }

  Future<void> toggle(String id) {
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    final snapshot = saved.toList();
    notifyListeners();
    // Serialize writes so rapid taps cannot persist an older selection last.
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      if (!await preferences.setStringList('saved_recipes', snapshot)) {
        throw StateError('Could not save favorites.');
      }
    });
    return _pendingSave;
  }

  Future<void> deleteRecipe(String id) async {
    recipes.removeWhere((r) => r.id == id);
    saved.remove(id);
    deletedIds.add(id);

    final savedSnapshot = saved.toList();
    final deletedSnapshot = deletedIds.toList();

    notifyListeners();

    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      await preferences.setStringList('saved_recipes', savedSnapshot);
      await preferences.setStringList('deleted_recipes', deletedSnapshot);

      final imports = recipes
          .where((r) => r.sourceUrl != null)
          .map((r) => jsonEncode(r.toJson()))
          .toList();
      await preferences.setStringList('imported_recipes', imports);

      final communityList = recipes
          .where((r) => r.isCommunity)
          .map((r) => jsonEncode(r.toJson()))
          .toList();
      await preferences.setStringList('community_recipes', communityList);
    });
    return _pendingSave;
  }
}

Future<void> saveRecipe(
  BuildContext context,
  RecipeStore store,
  String id,
) async {
  try {
    await store.toggle(id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Favorites changed for this session, but could not be saved on this device.',
          ),
        ),
      );
    }
  }
}

Future<bool> confirmDeleteRecipe(
  BuildContext context,
  RecipeStore store,
  Recipe recipe,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Recipe'),
      content: Text('Are you sure you want to delete "${recipe.name}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await store.deleteRecipe(recipe.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.name}" has been deleted.'),
        ),
      );
    }
    return true;
  }
  return false;
}

class DeliciousApp extends StatelessWidget {
  final RecipeStore store;
  const DeliciousApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Delicious',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: coral,
        primary: coral,
        surface: paper,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: Color(0xFF38333D),
        ),
        titleLarge: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(fontSize: 13, color: muted, height: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEE9EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEE9EF)),
        ),
      ),
    ),
    home: KitchenScreen(store: store),
  );
}

class KitchenScreen extends StatefulWidget {
  final RecipeStore store;
  const KitchenScreen({super.key, required this.store});
  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  int destination = 0;
  String category = 'All', query = '';
  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  final browseKey = GlobalKey();
  @override
  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void openRecipe(Recipe recipe) {
    if (MediaQuery.sizeOf(context).width < 760) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetails(recipe: recipe, store: widget.store),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470, maxHeight: 800),
            child: RecipeDetails(
              recipe: recipe,
              store: widget.store,
              dialog: true,
            ),
          ),
        ),
      );
    }
  }

  Future<void> importRecipe() async {
    final recipe = await showDialog<Recipe>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportRecipeDialog(
        importer: widget.store.importer,
        onSave: widget.store.addImported,
      ),
    );
    if (!mounted || recipe == null) {
      return;
    }
    searchController.clear();
    setState(() {
      destination = 0;
      category = 'All';
      query = '';
    });
    openRecipe(recipe);
  }

  Future<void> openAddCommunityRecipeDialog() async {
    final recipe = await showDialog<Recipe>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateCommunityRecipeDialog(
        onSave: widget.store.addCommunityRecipe,
      ),
    );
    if (!mounted || recipe == null) {
      return;
    }
    searchController.clear();
    setState(() {
      destination = 2;
      category = 'All';
      query = '';
    });
    openRecipe(recipe);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final visible = widget.store.recipes
            .where(
              (r) =>
                  (destination == 0 ||
                      (destination == 1 && widget.store.saved.contains(r.id)) ||
                      (destination == 2 && r.isCommunity)) &&
                  (category == 'All' || category == r.category) &&
                  (r.name.toLowerCase().contains(query) ||
                      r.ingredients.any(
                        (i) => i[1].toLowerCase().contains(query),
                      )),
            )
            .toList();
        return Scaffold(
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFFFEAF0),
                  selectedIndex: destination,
                  onDestinationSelected: (index) =>
                      setState(() => destination = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded, color: coral),
                      label: 'Discover',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.favorite_border),
                      selectedIcon: Icon(Icons.favorite, color: coral),
                      label: 'Saved recipes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people, color: coral),
                      label: 'Community',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) SizedBox(width: 220, child: sidebar()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(desktop ? 36 : 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'A little inspiration for your day',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              destination == 0
                                  ? 'What sounds delicious?'
                                  : destination == 1
                                  ? 'Your saved recipes'
                                  : 'Community Kitchen',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 28),
                            if (destination == 0) ...[
                              WelcomeBanner(
                                onImport: importRecipe,
                                onExplore: () {
                                  Scrollable.ensureVisible(
                                    browseKey.currentContext!,
                                    duration: const Duration(milliseconds: 300),
                                  );
                                  searchFocus.requestFocus();
                                },
                              ),
                              const SizedBox(height: 30),
                            ] else if (destination == 2) ...[
                              CommunityBanner(
                                onAddRecipe: openAddCommunityRecipeDialog,
                              ),
                              const SizedBox(height: 30),
                            ],
                            LayoutBuilder(
                              key: browseKey,
                              builder: (context, size) {
                                final title = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FIND YOUR NEXT FAVORITE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.5,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Explore recipes',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
                                );
                                final search = TextField(
                                  key: const Key('recipe-search'),
                                  controller: searchController,
                                  focusNode: searchFocus,
                                  onChanged: (value) => setState(
                                    () => query = value.trim().toLowerCase(),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search your perfect recipe',
                                    hintStyle: const TextStyle(fontSize: 12),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 21,
                                    ),
                                    suffixIcon: query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: () {
                                              searchController.clear();
                                              setState(() => query = '');
                                            },
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                          ),
                                  ),
                                );
                                return size.maxWidth > 600
                                    ? Row(
                                        children: [
                                          Expanded(child: title),
                                          SizedBox(width: 300, child: search),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          title,
                                          const SizedBox(height: 18),
                                          search,
                                        ],
                                      );
                              },
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children:
                                  [
                                    'All',
                                    'Breakfast',
                                    'Asian food',
                                    'Community Specials',
                                    'Imported',
                                  ]
                                      .map(
                                        (value) => ChoiceChip(
                                          label: Text(value),
                                          selected: category == value,
                                          showCheckmark: false,
                                          selectedColor: coral,
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          labelStyle: TextStyle(
                                            color: category == value
                                                ? Colors.white
                                                : muted,
                                            fontSize: 12,
                                          ),
                                          side: BorderSide(
                                            color: category == value
                                                ? coral
                                                : const Color(0xFFEEE9EF),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 13,
                                            vertical: 8,
                                          ),
                                          onSelected: (_) =>
                                              setState(() => category = value),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    destination == 0
                                        ? 'Popular right now'
                                        : 'Your collection',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${visible.length} recipe${visible.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (visible.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(45),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Text(
                                  'No recipes found.\nTry another search or save a recipe to your collection.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, size) {
                                  final columns = size.maxWidth > 850
                                      ? 4
                                      : size.maxWidth < 310
                                      ? 1
                                      : 2;
                                  final width =
                                      (size.maxWidth - (columns - 1) * 16) /
                                      columns;
                                  return Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: visible
                                        .map(
                                          (recipe) => SizedBox(
                                            width: width,
                                            child: RecipeCard(
                                              recipe: recipe,
                                              saved: widget.store.saved
                                                  .contains(recipe.id),
                                              onOpen: () => openRecipe(recipe),
                                              onSave: () => saveRecipe(
                                                context,
                                                widget.store,
                                                recipe.id,
                                              ),
                                              onDelete: () =>
                                                  confirmDeleteRecipe(
                                                    context,
                                                    widget.store,
                                                    recipe,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                            const SizedBox(height: 28),
                            const Center(
                              child: Text(
                                'Made with love. Shared around the table.',
                                style: TextStyle(fontSize: 10, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget sidebar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: Color(0xFFEEE9EF))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.spa_outlined, color: coral, size: 31),
            SizedBox(width: 9),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'delicious.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 45),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 16),
          child: Text(
            'YOUR KITCHEN',
            style: TextStyle(fontSize: 9, letterSpacing: 1.8, color: muted),
          ),
        ),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                selected: destination == i,
                selectedColor: coral,
                selectedTileColor: const Color(0xFFFFF0F3),
                leading: Icon(
                  i == 0
                      ? Icons.home_outlined
                      : i == 1
                      ? Icons.favorite_border
                      : Icons.people_outline,
                  size: 23,
                ),
                title: Text(
                  i == 0
                      ? 'Discover'
                      : i == 1
                      ? 'Saved recipes'
                      : 'Community',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: i == 1
                    ? Text(
                        '${widget.store.saved.length}',
                        style: const TextStyle(fontSize: 11),
                      )
                    : i == 2
                    ? Text(
                        '${widget.store.recipes.where((r) => r.isCommunity).length}',
                        style: const TextStyle(fontSize: 11),
                      )
                    : null,
                onTap: () => setState(() => destination = i),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: Color(0xFFD895A6)),
              SizedBox(height: 12),
              Text(
                'A little kitchen magic.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 7),
              Text(
                'Good food. Simple recipes.\nSomething to look forward to.',
                style: TextStyle(fontSize: 11, color: muted, height: 1.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Divider(color: Color(0xFFEEE9EF)),
        const SizedBox(height: 12),
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFF4D8E0),
              child: Text('Y', style: TextStyle(color: Color(0xFFB3667D))),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your kitchen', style: TextStyle(fontSize: 12)),
                  Text(
                    'A space for your favorites',
                    style: TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class WelcomeBanner extends StatelessWidget {
  final VoidCallback onExplore, onImport;
  const WelcomeBanner({
    super.key,
    required this.onExplore,
    required this.onImport,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(23),
    child: Container(
      width: double.infinity,
      color: const Color(0xFFF6E2E7),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 230,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.transparent, Colors.white],
                stops: [0, .7],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: .55,
                child: Image.asset('assets/welcome.webp', fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A little inspiration. A lot of flavor.',
                  style: TextStyle(fontSize: 10, color: Color(0xFFBD7188)),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Your next favorite\nstarts in your kitchen.',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                    color: Color(0xFF43333E),
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Simple ingredients. A little creativity. A plate full of joy.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFA27A8B)),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onExplore,
                      label: const Text(
                        'Explore recipes',
                        style: TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.north_east, size: 18),
                    ),
                    OutlinedButton.icon(
                      onPressed: onImport,
                      icon: const Icon(Icons.add_link, size: 18),
                      label: const Text('Import recipe'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool saved;
  final VoidCallback onOpen, onSave, onDelete;
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFEFEBF1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        InkWell(
          onTap: onOpen,
          child: Semantics(
            button: true,
            label: 'View ${recipe.name} recipe',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 27, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecipeArtwork(
                    recipe: recipe,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 15,
                    runSpacing: 4,
                    children: [
                      Text(
                        recipe.timeLabel,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      Text(
                        '★ ${recipe.rating}',
                        style: const TextStyle(fontSize: 11, color: coral),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Delete ${recipe.name}',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: muted,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: '${saved ? 'Unsave' : 'Save'} ${recipe.name}',
                onPressed: onSave,
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: saved ? coral : muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RecipeDetails extends StatefulWidget {
  final Recipe recipe;
  final RecipeStore store;
  final bool dialog;
  const RecipeDetails({
    super.key,
    required this.recipe,
    required this.store,
    this.dialog = false,
  });
  @override
  State<RecipeDetails> createState() => _RecipeDetailsState();
}

class _RecipeDetailsState extends State<RecipeDetails> {
  bool showSteps = false;
  int stepIndex = 0;
  double userSelectedStars = 5.0;

  Widget stepPage(Recipe recipe) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Step ${stepIndex + 1} of ${recipe.steps.length}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (stepIndex + 1) / recipe.steps.length,
            ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: ValueKey(stepIndex),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RecipeArtwork(
                  recipe: recipe,
                  imageOverride: recipe.imageForStep(stepIndex),
                  height: 230,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  semanticLabel: 'Image for step ${stepIndex + 1}',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                recipe.steps[stepIndex],
                style: const TextStyle(fontSize: 18, height: 1.6),
              ),
            ],
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  if (stepIndex > 0) {
                    stepIndex--;
                  } else {
                    showSteps = false;
                  }
                }),
                child: Text(stepIndex == 0 ? 'Details' : 'Previous'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => setState(() {
                  if (stepIndex < recipe.steps.length - 1) {
                    stepIndex++;
                  } else {
                    showSteps = false;
                    stepIndex = 0;
                  }
                }),
                icon: Icon(
                  stepIndex == recipe.steps.length - 1
                      ? Icons.check
                      : Icons.arrow_forward,
                ),
                label: Text(
                  stepIndex == recipe.steps.length - 1 ? 'Done' : 'Next step',
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final recipe = widget.recipe;
      final saved = widget.store.saved.contains(recipe.id);
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back to recipes',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Back to recipes', style: TextStyle(fontSize: 13)),
          actions: [
            IconButton(
              tooltip: '${saved ? 'Unsave' : 'Save'} ${recipe.name}',
              onPressed: () => saveRecipe(context, widget.store, recipe.id),
              icon: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                color: coral,
              ),
            ),
            IconButton(
              tooltip: 'Delete ${recipe.name}',
              icon: const Icon(Icons.delete_outline, color: muted),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final deleted = await confirmDeleteRecipe(
                  context,
                  widget.store,
                  recipe,
                );
                if (deleted && navigator.canPop()) {
                  navigator.pop();
                }
              },
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: showSteps && recipe.steps.isNotEmpty
            ? stepPage(recipe)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecipeArtwork(
                      recipe: recipe,
                      width: double.infinity,
                      height: 235,
                      fit: BoxFit.contain,
                      semanticLabel: recipe.name,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 15, color: muted),
                            const SizedBox(width: 5),
                            Text(recipe.timeLabel),
                          ],
                        ),
                        Text(
                          '★ ${recipe.rating}',
                          style: const TextStyle(color: coral),
                        ),
                      ],
                    ),
                    if (recipe.sourceUrl != null) ...[
                      const SizedBox(height: 16),
                      const Text('Original recipe'),
                      SelectableText(recipe.sourceUrl!),
                    ],
                    const SizedBox(height: 25),
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF43333E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: recipe.ingredients
                          .map(
                            (ingredient) => Tooltip(
                              message: ingredient[1],
                              child: Semantics(
                                label: ingredient[1],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8DCE2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${ingredient[0]} ${ingredient[1]}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6A4B5F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 25),
                    Center(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Details')),
                          ButtonSegment(value: true, label: Text('Recipe')),
                        ],
                        selected: {showSteps},
                        onSelectionChanged: (value) =>
                            setState(() => showSteps = value.single),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(recipe.description),
                    for (final notice in recipe.notices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Recipe notice: $notice',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEE9EF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: coral,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Rate this Recipe',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF43333E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Current Score: ${recipe.rating} ★ (${recipe.ratingCount} ${recipe.ratingCount == 1 ? 'rating' : 'ratings'})',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Your Rating: ', style: TextStyle(fontSize: 12)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (index) {
                                  final starValue = index + 1;
                                  return IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    icon: Icon(
                                      starValue <= userSelectedStars
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: coral,
                                      size: 24,
                                    ),
                                    tooltip: 'Rate $starValue Stars',
                                    onPressed: () async {
                                      setState(
                                        () => userSelectedStars =
                                            starValue.toDouble(),
                                      );
                                      await widget.store.rateRecipe(
                                        recipe.id,
                                        starValue.toDouble(),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Thanks for rating "${recipe.name}" $starValue stars!',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => showSteps = !showSteps),
                        child: Text(
                          showSteps ? 'Back to details' : "Let's cook",
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Center(
                      child: Text(
                        'A little time in the kitchen, a little joy.',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}

class RecipeArtwork extends StatelessWidget {
  final Recipe recipe;
  final double height, width;
  final BoxFit fit;
  final bool excludeFromSemantics;
  final String? semanticLabel;
  final String? imageOverride;
  const RecipeArtwork({
    super.key,
    required this.recipe,
    required this.height,
    required this.width,
    required this.fit,
    this.excludeFromSemantics = false,
    this.semanticLabel,
    this.imageOverride,
  });
  @override
  Widget build(BuildContext context) {
    final image = imageOverride ?? recipe.image;
    Widget placeholder() => Container(
      height: height,
      width: width,
      color: const Color(0xFFF8DCE2),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 40, color: coral),
          SizedBox(height: 6),
          Text('No photo available', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
    if (image.isEmpty) return placeholder();
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(
        image,
        height: height,
        width: width,
        fit: fit,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        errorBuilder: (_, error, stack) => placeholder(),
      );
    }
    return Image.asset(
      image,
      height: height,
      width: width,
      fit: fit,
      excludeFromSemantics: excludeFromSemantics,
      semanticLabel: semanticLabel,
      errorBuilder: (_, error, stack) => placeholder(),
    );
  }
}

class CommunityBanner extends StatelessWidget {
  final VoidCallback onAddRecipe;
  const CommunityBanner({super.key, required this.onAddRecipe});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(23),
    child: Container(
      width: double.infinity,
      color: const Color(0xFFFFF0F3),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.people,
                  color: coral,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  "COMMUNITY KITCHEN",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Recipes shared by food lovers,\nfor everyone.',
              style: TextStyle(
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
                color: Color(0xFF43333E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Share your homemade creations, family recipes, or favorite meals. Rate and support dishes from others!',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddRecipe,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Upload a Recipe'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CreateCommunityRecipeDialog extends StatefulWidget {
  final Future<Recipe> Function(Recipe) onSave;
  const CreateCommunityRecipeDialog({super.key, required this.onSave});

  @override
  State<CreateCommunityRecipeDialog> createState() =>
      _CreateCommunityRecipeDialogState();
}

class _CreateCommunityRecipeDialogState
    extends State<CreateCommunityRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final timeController = TextEditingController(text: '30');
  final descController = TextEditingController();
  final ingredientsController = TextEditingController();
  final stepsController = TextEditingController();
  final imageController = TextEditingController();
  String category = 'Community Specials';
  bool busy = false;

  final categories = [
    'Community Specials',
    'Home Cooking',
    'Breakfast',
    'Asian food',
    'Desserts',
    'Quick & Easy',
  ];

  @override
  void dispose() {
    nameController.dispose();
    timeController.dispose();
    descController.dispose();
    ingredientsController.dispose();
    stepsController.dispose();
    imageController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => busy = true);

    final rawIngredients = ingredientsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => ['•', s])
        .toList();

    final rawSteps = stepsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final recipe = Recipe.fromJson({
      'id': 'community:${DateTime.now().millisecondsSinceEpoch}',
      'name': nameController.text.trim(),
      'category': category,
      'time': int.tryParse(timeController.text.trim()) ?? 30,
      'description': descController.text.trim(),
      'ingredients': rawIngredients.isEmpty
          ? [
              ['•', 'Special ingredients'],
            ]
          : rawIngredients,
      'steps': rawSteps.isEmpty
          ? ['Cook with passion and enjoy!']
          : rawSteps,
      'rating': '5.0',
      'ratingCount': 1,
      'ratingSum': 5.0,
      'image': imageController.text.trim().isEmpty
          ? 'assets/welcome.webp'
          : imageController.text.trim(),
      'isCommunity': true,
    });

    try {
      final saved = await widget.onSave(recipe);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.people, color: coral),
        SizedBox(width: 8),
        Text('Upload a Recipe'),
      ],
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Recipe Title',
                  hintText: 'e.g., Homemade Garlic Butter Pasta',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Time (minutes)',
                  hintText: '30',
                ),
                validator: (v) =>
                    v == null || int.tryParse(v.trim()) == null
                        ? 'Enter time in minutes'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description / Story',
                  hintText: 'Tell us what makes this recipe special...',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ingredientsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)',
                  hintText:
                      "1/2 lb Pasta\n3 cloves Garlic\n2 tbsp Butter",
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: stepsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Cooking Steps (one per line)',
                  hintText:
                      "Boil pasta until al dente.\nSauté garlic in butter.\nToss pasta and serve!",
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  hintText: 'https://example.com/photo.jpg',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: const Text('Upload Recipe'),
      ),
    ],
  );
}

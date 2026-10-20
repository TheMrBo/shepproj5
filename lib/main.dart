import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class Recipe {
  final String id, name, category, image, rating, description;
  final int time;
  final List<List<String>> ingredients;
  final List<String> steps;
  Recipe.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      category = json['category'] as String,
      image = 'assets/${json['image']}.webp',
      rating = json['rating'] as String,
      description = json['description'] as String,
      time = json['time'] as int,
      ingredients = (json['ingredients'] as List)
          .map((e) => List<String>.from(e as List))
          .toList(),
      steps = List<String>.from(json['steps'] as List);
}

class RecipeStore extends ChangeNotifier {
  final List<Recipe> recipes;
  final SharedPreferences preferences;
  late final Set<String> saved =
      (preferences.getStringList('saved_recipes') ?? ['ramen', 'salad'])
          .toSet();
  Future<void> _pendingSave = Future.value();
  RecipeStore(this.recipes, this.preferences);
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final visible = widget.store.recipes
            .where(
              (r) =>
                  (destination == 0 || widget.store.saved.contains(r.id)) &&
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
                                  : 'Your saved recipes',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 28),
                            if (destination == 0) ...[
                              WelcomeBanner(
                                onExplore: () {
                                  Scrollable.ensureVisible(
                                    browseKey.currentContext!,
                                    duration: const Duration(milliseconds: 300),
                                  );
                                  searchFocus.requestFocus();
                                },
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
                              children: ['All', 'Breakfast', 'Asian food']
                                  .map(
                                    (value) => ChoiceChip(
                                      label: Text(value),
                                      selected: category == value,
                                      showCheckmark: false,
                                      selectedColor: coral,
                                      backgroundColor: Colors.white,
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
        for (int i = 0; i < 2; i++)
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
                  i == 0 ? Icons.home_outlined : Icons.favorite_border,
                  size: 23,
                ),
                title: Text(
                  i == 0 ? 'Discover' : 'Saved recipes',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: i == 1
                    ? Text(
                        '${widget.store.saved.length}',
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
  final VoidCallback onExplore;
  const WelcomeBanner({super.key, required this.onExplore});
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
                FilledButton.icon(
                  onPressed: onExplore,
                  label: const Text(
                    'Explore recipes',
                    style: TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.north_east, size: 18),
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
  final VoidCallback onOpen, onSave;
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onOpen,
    required this.onSave,
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
                  Image.asset(
                    recipe.image,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    recipe.name,
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
                        '${recipe.time} min',
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
          top: 2,
          right: 2,
          child: IconButton(
            tooltip: '${saved ? 'Unsave' : 'Save'} ${recipe.name}',
            onPressed: onSave,
            icon: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              size: 21,
              color: saved ? coral : muted,
            ),
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
            const SizedBox(width: 10),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 8, 25, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                recipe.image,
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
              Row(
                children: [
                  const Icon(Icons.schedule, size: 15, color: muted),
                  const SizedBox(width: 5),
                  Text('${recipe.time} min'),
                  const SizedBox(width: 20),
                  Text(
                    '★ ${recipe.rating}',
                    style: const TextStyle(color: coral),
                  ),
                ],
              ),
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Details')),
                  ButtonSegment(value: true, label: Text('Recipe')),
                ],
                selected: {showSteps},
                onSelectionChanged: (value) =>
                    setState(() => showSteps = value.single),
              ),
              const SizedBox(height: 20),
              if (!showSteps)
                Text(recipe.description)
              else
                ...recipe.steps.indexed.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 17),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFFF8DCE2),
                          child: Text(
                            '${step.$1 + 1}',
                            style: const TextStyle(fontSize: 11, color: coral),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(step.$2)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => showSteps = !showSteps),
                  child: Text(showSteps ? 'Back to details' : "Let's cook"),
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

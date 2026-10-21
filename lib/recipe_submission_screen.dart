import 'package:flutter/material.dart';
import 'recipe.dart';
import 'recipe_attribution_legal.dart';
import 'step_timer_widget.dart';

class IngredientFormInput {
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController nameController;

  IngredientFormInput({
    String quantity = '',
    String unit = '',
    String name = '',
  })  : quantityController = TextEditingController(text: quantity),
        unitController = TextEditingController(text: unit),
        nameController = TextEditingController(text: name);

  List<String> toIngredientPair() {
    final qtyUnit = [quantityController.text.trim(), unitController.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final name = nameController.text.trim();
    return [qtyUnit.isEmpty ? '•' : qtyUnit, name];
  }

  bool get isValid => nameController.text.trim().isNotEmpty;

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    nameController.dispose();
  }
}

class InstructionStepFormInput {
  final TextEditingController directionController;
  Duration? timerDuration;

  InstructionStepFormInput({
    String directionText = '',
    this.timerDuration,
  }) : directionController = TextEditingController(text: directionText);

  String get directionText => directionController.text.trim();
  bool get isValid => directionText.isNotEmpty;

  InstructionStep toInstructionStep(int stepNumber) => InstructionStep(
        stepNumber: stepNumber,
        directionText: directionText,
        timerDuration: timerDuration,
      );

  void dispose() {
    directionController.dispose();
  }
}

class RecipeSubmissionScreen extends StatefulWidget {
  final Recipe? initialRecipe; // If provided, Edit Mode; if null, Create Mode
  final Future<Recipe> Function(Recipe) onSave;

  const RecipeSubmissionScreen({
    super.key,
    this.initialRecipe,
    required this.onSave,
  });

  bool get isEditMode => initialRecipe != null;

  @override
  State<RecipeSubmissionScreen> createState() =>
      _RecipeSubmissionScreenState();
}

class _RecipeSubmissionScreenState extends State<RecipeSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _timeController;
  late final TextEditingController _authorNameController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _descriptionController;

  // Attribution
  late bool _isAdapted;
  late final TextEditingController _sourceNameController;
  late final TextEditingController _sourceUrlController;

  // Legal certification
  bool _isLegalCertified = false;

  late String _category;
  bool _busy = false;
  String? _validationError;

  final List<IngredientFormInput> _ingredientInputs = [];
  final List<InstructionStepFormInput> _instructionInputs = [];

  final List<String> _categories = [
    'Home Cooking',
    'Community Specials',
    'Breakfast',
    'Asian food',
    'Desserts',
    'Quick & Easy',
    'BBQ & Grill',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecipe;

    // STATE PRESERVATION: Intact initialization from initialRecipe if present
    _titleController = TextEditingController(text: init?.name ?? '');
    _timeController = TextEditingController(text: '${init?.time ?? 30}');
    _authorNameController =
        TextEditingController(text: init?.authorName ?? 'Chef Alex');
    // STATE PRESERVATION: Explicitly preserve image URL reference without resetting
    _imageUrlController = TextEditingController(text: init?.image ?? '');
    _descriptionController =
        TextEditingController(text: init?.description ?? '');

    _isAdapted = init?.isAdapted ?? false;
    _sourceNameController =
        TextEditingController(text: init?.sourceName ?? '');
    _sourceUrlController =
        TextEditingController(text: init?.sourceUrl ?? '');

    _category = init != null && _categories.contains(init.category)
        ? init.category
        : 'Home Cooking';

    // Populate ingredients from initial recipe while preserving state
    if (init != null && init.ingredients.isNotEmpty) {
      for (final pair in init.ingredients) {
        final qtyUnit = pair.isNotEmpty ? pair[0] : '';
        final name = pair.length > 1 ? pair[1] : (pair.isNotEmpty ? pair[0] : '');
        _ingredientInputs.add(IngredientFormInput(
          quantity: qtyUnit.replaceAll('•', '').trim(),
          name: name,
        ));
      }
    } else {
      _ingredientInputs.add(IngredientFormInput());
    }

    // Populate steps from initial recipe while preserving state and timer durations
    if (init != null && init.instructions.isNotEmpty) {
      for (final step in init.instructions) {
        _instructionInputs.add(InstructionStepFormInput(
          directionText: step.directionText,
          timerDuration: step.timerDuration,
        ));
      }
    } else if (init != null && init.steps.isNotEmpty) {
      for (final step in init.steps) {
        _instructionInputs.add(InstructionStepFormInput(directionText: step));
      }
    } else {
      _instructionInputs.add(InstructionStepFormInput());
    }
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientInputs.add(IngredientFormInput());
    });
  }

  void _removeIngredientRow(int index) {
    if (_ingredientInputs.length <= 1) return;
    setState(() {
      final removed = _ingredientInputs.removeAt(index);
      removed.dispose();
    });
  }

  void _addInstructionRow() {
    setState(() {
      _instructionInputs.add(InstructionStepFormInput());
    });
  }

  void _removeInstructionRow(int index) {
    if (_instructionInputs.length <= 1) return;
    setState(() {
      final removed = _instructionInputs.removeAt(index);
      removed.dispose();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _authorNameController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _sourceNameController.dispose();
    _sourceUrlController.dispose();

    for (final input in _ingredientInputs) {
      input.dispose();
    }
    for (final input in _instructionInputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRecipe() async {
    setState(() => _validationError = null);

    if (!_formKey.currentState!.validate()) return;

    if (!_isLegalCertified) {
      setState(() {
        _validationError =
            'You must certify copyright ownership before publishing.';
      });
      return;
    }

    final validIngredients = _ingredientInputs
        .where((i) => i.isValid)
        .map((i) => i.toIngredientPair())
        .toList();

    if (validIngredients.isEmpty) {
      setState(() {
        _validationError = 'Please add at least one ingredient with a name.';
      });
      return;
    }

    final validInstructions = <InstructionStep>[];
    for (var i = 0; i < _instructionInputs.length; i++) {
      if (_instructionInputs[i].isValid) {
        validInstructions.add(
          _instructionInputs[i].toInstructionStep(validInstructions.length + 1),
        );
      }
    }

    if (validInstructions.isEmpty) {
      setState(() {
        _validationError = 'Please add at least one cooking step.';
      });
      return;
    }

    setState(() => _busy = true);

    // CRITICAL STATE PRESERVATION RULE:
    // If _imageUrlController is empty or untouched in Edit mode, preserve original image!
    final finalImageUrl = _imageUrlController.text.trim().isNotEmpty
        ? _imageUrlController.text.trim()
        : (widget.initialRecipe?.image.isNotEmpty == true
            ? widget.initialRecipe!.image
            : 'assets/welcome.webp');

    final recipe = Recipe(
      id: widget.initialRecipe?.id ??
          'community:${DateTime.now().millisecondsSinceEpoch}',
      name: _titleController.text.trim(),
      category: _category,
      image: finalImageUrl,
      time: int.tryParse(_timeController.text.trim()) ??
          widget.initialRecipe?.time ??
          30,
      description: _descriptionController.text.trim(),
      ingredients: validIngredients,
      instructions: validInstructions,
      isCommunity: true,
      authorName: _authorNameController.text.trim().isEmpty
          ? (widget.initialRecipe?.authorName ?? 'Community Chef')
          : _authorNameController.text.trim(),
      postedDate: widget.initialRecipe?.postedDate ?? 'Just now',
      isAdapted: _isAdapted,
      sourceName: _isAdapted ? _sourceNameController.text.trim() : null,
      sourceUrl: _isAdapted ? _sourceUrlController.text.trim() : null,
      rating: widget.initialRecipe?.rating ?? '5.0',
      ratingCount: widget.initialRecipe?.ratingCount ?? 1,
      ratingSum: widget.initialRecipe?.ratingSum ?? 5.0,
    );

    try {
      final saved = await widget.onSave(recipe);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _validationError = 'Could not save recipe. Please try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode
            ? 'Edit Community Recipe'
            : 'Publish Community Recipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isEditMode ? 'Edit Recipe' : 'Share Your Recipe',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isEditMode
                        ? 'Update your recipe ingredients and steps without losing attached photos.'
                        : 'Enter your ingredients and cooking steps clearly. All submitted recipes must adhere to community guidelines.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),

                  if (_validationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // PRESERVED MEDIA PREVIEW IF PRESENT
                  if (_imageUrlController.text.trim().isNotEmpty ||
                      (widget.initialRecipe?.image.isNotEmpty == true)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrlController.text.trim().isNotEmpty
                                  ? _imageUrlController.text.trim()
                                  : widget.initialRecipe!.image,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.restaurant_menu,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attached Recipe Media',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Pre-existing photo reference is preserved.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 1. BASIC DETAILS
                  Text(
                    '1. Recipe Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Recipe Title *',
                      hintText: 'e.g., Creamy Mushroom Pasta',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: _categories
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _category = v ?? _category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _timeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Time (mins)',
                          ),
                          validator: (v) =>
                              v == null || int.tryParse(v.trim()) == null
                                  ? 'Enter mins'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _authorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name / Chef Handle',
                      hintText: 'e.g., Chef Alex',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Photo Image URL (optional)',
                      hintText: 'https://example.com/photo.jpg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Story / Overview',
                      hintText: 'What makes this recipe special...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. INGREDIENTS
                  Text(
                    '2. Ingredients',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _ingredientInputs.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 65,
                            child: TextFormField(
                              controller:
                                  _ingredientInputs[i].quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                hintText: '2',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              controller: _ingredientInputs[i].unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                hintText: 'cups',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller:
                                  _ingredientInputs[i].nameController,
                              decoration: const InputDecoration(
                                labelText: 'Ingredient Name *',
                                hintText: 'Flour',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _ingredientInputs.length > 1
                                ? () => _removeIngredientRow(i)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _addIngredientRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Ingredient'),
                  ),
                  const SizedBox(height: 24),

                  // 3. STEPS
                  Text(
                    '3. Cooking Steps',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _instructionInputs.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12, right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller:
                                  _instructionInputs[i].directionController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Direction Step *',
                                hintText: 'Describe this step...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _instructionInputs.length > 1
                                    ? () => _removeInstructionRow(i)
                                    : null,
                              ),
                              ActionChip(
                                avatar: Icon(
                                  _instructionInputs[i].timerDuration != null
                                      ? Icons.timer
                                      : Icons.timer_outlined,
                                  size: 14,
                                  color: _instructionInputs[i].timerDuration != null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                label: Text(
                                  _instructionInputs[i].timerDuration != null
                                      ? '${_instructionInputs[i].timerDuration!.inMinutes}m ${_instructionInputs[i].timerDuration!.inSeconds % 60}s'
                                      : '+ Timer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        _instructionInputs[i].timerDuration != null
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await showDialog<Duration>(
                                    context: context,
                                    builder: (_) => StepTimerPickerDialog(
                                      initialDuration:
                                          _instructionInputs[i].timerDuration,
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _instructionInputs[i].timerDuration =
                                          result.inSeconds > 0 ? result : null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _addInstructionRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Step'),
                  ),
                  const SizedBox(height: 24),

                  // 4. ATTRIBUTION TOGGLE
                  Text(
                    '4. Recipe Attribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text(
                      'Adapted from an existing recipe?',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Enable to credit the original chef or website.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isAdapted,
                    activeThumbColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isAdapted = val),
                  ),
                  if (_isAdapted) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sourceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Original Creator / Source Name *',
                        hintText: 'e.g., Chef John or Grandma\'s Book',
                      ),
                      validator: (v) => _isAdapted && (v == null || v.trim().isEmpty)
                          ? 'Enter creator or source name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _sourceUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Source Website URL (optional)',
                        hintText: 'https://example.com/recipe',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // 5. LEGAL CERTIFICATION WIDGET
                  RecipePublishLegalWidget(
                    isCertified: _isLegalCertified,
                    onCertifiedChanged: (val) {
                      setState(() {
                        _isLegalCertified = val;
                        if (val) _validationError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 28),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed:
                          _isLegalCertified && !_busy ? _submitRecipe : null,
                      child: _busy
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.isEditMode
                                  ? 'Update & Save Recipe'
                                  : 'Publish Recipe',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

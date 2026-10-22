String _stripEmojis(String text) {
  if (text.isEmpty) return '';
  final emojiRegExp = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
  );
  return text.replaceAll(emojiRegExp, '').trim();
}

class IngredientItem {
  final String id;
  final String quantity;
  final String unit;
  final String name;
  final String prepAction;
  final bool isPrepped;

  const IngredientItem({
    String? id,
    required this.quantity,
    required this.unit,
    required this.name,
    this.prepAction = '',
    this.isPrepped = false,
  }) : id = id ?? name;

  double get quantityNum => double.tryParse(quantity) ?? 0.0;

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    var rawName = _stripEmojis(json['name'] as String? ?? '');
    var rawAction = _stripEmojis(json['prepAction'] as String? ?? '');

    if (rawAction.isEmpty && rawName.contains(',')) {
      final parts = rawName.split(',');
      if (parts.length >= 2) {
        rawName = parts[0].trim();
        rawAction = parts.sublist(1).join(',').trim();
      }
    } else if (rawAction.isEmpty &&
        rawName.contains('(') &&
        rawName.endsWith(')')) {
      final start = rawName.indexOf('(');
      final end = rawName.lastIndexOf(')');
      if (start > 0 && end > start) {
        rawAction = rawName.substring(start + 1, end).trim();
        rawName = rawName.substring(0, start).trim();
      }
    }

    if (rawAction.isNotEmpty) {
      rawAction = rawAction[0].toUpperCase() + rawAction.substring(1);
    }

    final rawQty = json['quantity'];
    String qtyString = '';
    if (rawQty is num) {
      qtyString = rawQty.toString();
    } else if (rawQty is String) {
      qtyString = _stripEmojis(rawQty);
    }

    return IngredientItem(
      id: json['id'] as String? ?? rawName,
      quantity: qtyString,
      unit: _stripEmojis(json['unit'] as String? ?? ''),
      name: rawName,
      prepAction: rawAction,
      isPrepped: json['isPrepped'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quantity': quantity,
        'unit': unit,
        'name': name,
        'prepAction': prepAction,
        'isPrepped': isPrepped,
      };

  IngredientItem copyWith({
    String? id,
    String? quantity,
    String? unit,
    String? name,
    String? prepAction,
    bool? isPrepped,
  }) {
    return IngredientItem(
      id: id ?? this.id,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      name: name ?? this.name,
      prepAction: prepAction ?? this.prepAction,
      isPrepped: isPrepped ?? this.isPrepped,
    );
  }

  String get displayText {
    final cleanQty = _stripEmojis(quantity);
    final cleanUnit = _stripEmojis(unit);
    final cleanName = _stripEmojis(name);

    final parts =
        [cleanQty, cleanUnit, cleanName].where((s) => s.trim().isNotEmpty);
    final baseText = parts.isEmpty ? 'Ingredient' : parts.join(' ');
    if (prepAction.isNotEmpty) {
      return '$baseText • ${_stripEmojis(prepAction)}';
    }
    return baseText;
  }
}

typedef RecipeIngredient = IngredientItem;

class InstructionStep {
  final int stepNumber;
  final String directionText;
  final Duration? timerDuration;
  final List<String> ingredientNames;
  final List<String> ingredientIds;
  final String? imageUrl;

  const InstructionStep({
    required this.stepNumber,
    required this.directionText,
    this.timerDuration,
    this.ingredientNames = const [],
    this.ingredientIds = const [],
    this.imageUrl,
  });

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    Duration? timer;
    if (json['timerDurationSeconds'] != null) {
      timer = Duration(seconds: json['timerDurationSeconds'] as int);
    } else if (json['timerDurationInSeconds'] != null) {
      timer = Duration(seconds: json['timerDurationInSeconds'] as int);
    }
    return InstructionStep(
      stepNumber: json['stepNumber'] as int? ?? 1,
      directionText: json['directionText'] as String? ?? '',
      timerDuration: timer,
      ingredientNames:
          List<String>.from(json['ingredientNames'] as List? ?? []),
      ingredientIds: List<String>.from(json['ingredientIds'] as List? ?? []),
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'directionText': directionText,
        if (timerDuration != null)
          'timerDurationSeconds': timerDuration!.inSeconds,
        if (ingredientNames.isNotEmpty) 'ingredientNames': ingredientNames,
        if (ingredientIds.isNotEmpty) 'ingredientIds': ingredientIds,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  List<IngredientItem> filterRelevantIngredients(
      List<IngredientItem> allIngredients) {
    if (allIngredients.isEmpty) return [];

    final text = directionText.toLowerCase();
    return allIngredients.where((ingredient) {
      if (ingredientIds.contains(ingredient.id)) return true;
      if (ingredientNames.contains(ingredient.name)) return true;

      final nameLower = ingredient.name.toLowerCase().trim();
      if (nameLower.isEmpty) return false;

      if (text.contains(nameLower)) return true;

      final words = nameLower.split(RegExp(r'\s+')).where((w) =>
          w.length > 2 &&
          !const {
            'and',
            'the',
            'for',
            'with',
            'fresh',
            'large',
            'medium',
            'small'
          }.contains(w));

      return words.any((word) => text.contains(word));
    }).toList();
  }

  InstructionStep copyWith({
    int? stepNumber,
    String? directionText,
    Duration? timerDuration,
    List<String>? ingredientNames,
    List<String>? ingredientIds,
    String? imageUrl,
    bool clearTimer = false,
  }) {
    return InstructionStep(
      stepNumber: stepNumber ?? this.stepNumber,
      directionText: directionText ?? this.directionText,
      timerDuration: clearTimer ? null : (timerDuration ?? this.timerDuration),
      ingredientNames: ingredientNames ?? this.ingredientNames,
      ingredientIds: ingredientIds ?? this.ingredientIds,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

typedef RecipeStep = InstructionStep;

class RecipeAttribution {
  final String sourceName;
  final String sourceUrl;
  final bool isAdapted;

  const RecipeAttribution({
    required this.sourceName,
    required this.sourceUrl,
    required this.isAdapted,
  });

  factory RecipeAttribution.fromJson(Map<String, dynamic> json) =>
      RecipeAttribution(
        sourceName: json['sourceName'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        isAdapted: json['isAdapted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'isAdapted': isAdapted,
      };
}

class Recipe {
  final String id;
  final String name;
  final String category;
  final String image;
  final String rating;
  final String description;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int time;
  final int servings;
  final List<IngredientItem> ingredientItems;
  final List<InstructionStep> instructions;
  final List<List<String>> ingredients;
  final List<String> steps;
  final List<String> stepImages;
  final List<String> notices;
  final bool isCommunity;
  final int ratingCount;
  final double ratingSum;

  // Author & Attribution fields
  final String authorName;
  final String postedDate;
  final bool isAdapted;
  final String? sourceName;
  final String? sourceUrl;

  Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    this.rating = '5.0',
    this.description = '',
    this.prepTimeMinutes = 15,
    this.cookTimeMinutes = 15,
    int? time,
    this.servings = 4,
    List<IngredientItem>? ingredientItems,
    List<InstructionStep>? instructions,
    List<List<String>>? ingredients,
    List<String>? steps,
    this.stepImages = const [],
    this.notices = const [],
    this.isCommunity = false,
    this.ratingCount = 1,
    this.ratingSum = 5.0,
    this.authorName = 'Community Chef',
    this.postedDate = 'Today',
    this.isAdapted = false,
    this.sourceName,
    this.sourceUrl,
  })  : time = time ?? (prepTimeMinutes + cookTimeMinutes),
        ingredientItems = ingredientItems ??
            (ingredients != null
                ? ingredients
                    .map((pair) => IngredientItem(
                          quantity: pair.isNotEmpty ? pair[0] : '',
                          unit: '',
                          name: pair.length > 1 ? pair[1] : (pair.isNotEmpty ? pair[0] : ''),
                        ))
                    .toList()
                : []),
        instructions = instructions ??
            (steps != null
                ? steps
                    .asMap()
                    .entries
                    .map((entry) => InstructionStep(
                          stepNumber: entry.key + 1,
                          directionText: entry.value,
                        ))
                    .toList()
                : []),
        ingredients = ingredients ??
            (ingredientItems != null
                ? ingredientItems
                    .map((item) => ['•', item.displayText])
                    .toList()
                : []),
        steps = steps ??
            (instructions != null
                ? instructions.map((item) => item.directionText).toList()
                : []);

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawSourceUrl = json['sourceUrl'] as String?;
    final rawSourceName = json['sourceName'] as String?;
    final rawIsAdapted = json['isAdapted'] as bool? ??
        (rawSourceUrl != null && rawSourceUrl.isNotEmpty);

    final rawName = json['name'] as String? ?? json['title'] as String? ?? 'Recipe';

    // Format image path correctly for network URLs, asset paths, and recipe keys
    final rawImage = json['image'] as String? ?? json['imageUrl'] as String? ?? '';
    String formattedImage;
    if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
      formattedImage = rawImage;
    } else if (rawImage.startsWith('assets/')) {
      formattedImage = rawImage;
    } else if (rawImage.isNotEmpty) {
      formattedImage = 'assets/$rawImage.webp';
    } else {
      formattedImage = 'assets/welcome.webp';
    }

    // Parse ingredientItems or legacy ingredients
    List<IngredientItem> parsedItems = [];
    List<List<String>> parsedLegacyIngredients = [];
    if (json['ingredientItems'] != null) {
      parsedItems = (json['ingredientItems'] as List)
          .map((e) => IngredientItem.fromJson(e as Map<String, dynamic>))
          .toList();
      parsedLegacyIngredients =
          parsedItems.map((item) => ['•', item.displayText]).toList();
    } else if (json['ingredients'] != null) {
      parsedLegacyIngredients = (json['ingredients'] as List)
          .map((e) => List<String>.from(e as List))
          .toList();
      parsedItems = parsedLegacyIngredients
          .map((pair) => IngredientItem(
                quantity: pair.isNotEmpty ? pair[0] : '',
                unit: '',
                name: pair.length > 1 ? pair[1] : (pair.isNotEmpty ? pair[0] : ''),
              ))
          .toList();
    }

    // Parse instructions or legacy steps
    List<InstructionStep> parsedInstructionSteps = [];
    List<String> parsedLegacySteps = [];
    if (json['instructions'] != null) {
      parsedInstructionSteps = (json['instructions'] as List)
          .map((e) => InstructionStep.fromJson(e as Map<String, dynamic>))
          .toList();
      parsedLegacySteps =
          parsedInstructionSteps.map((e) => e.directionText).toList();
    } else if (json['steps'] != null) {
      parsedLegacySteps = List<String>.from(json['steps'] as List);
      parsedInstructionSteps = parsedLegacySteps
          .asMap()
          .entries
          .map((e) => InstructionStep(
                stepNumber: e.key + 1,
                directionText: e.value,
              ))
          .toList();
    }

    final totalT = json['time'] as int? ?? 30;
    final prepT = json['prepTimeMinutes'] as int? ?? (totalT / 2).round();
    final cookT = json['cookTimeMinutes'] as int? ?? (totalT / 2).floor();

    return Recipe(
      id: json['id'] as String? ?? '',
      name: rawName,
      category: json['category'] as String? ?? 'General',
      image: formattedImage,
      rating: json['rating'] as String? ?? '5.0',
      description: json['description'] as String? ?? json['chefNotes'] as String? ?? '',
      prepTimeMinutes: prepT,
      cookTimeMinutes: cookT,
      time: totalT,
      servings: json['servings'] as int? ?? 4,
      ingredientItems: parsedItems,
      instructions: parsedInstructionSteps,
      ingredients: parsedLegacyIngredients,
      steps: parsedLegacySteps,
      stepImages: List<String>.from(json['stepImages'] as List? ?? []),
      notices: List<String>.from(json['notices'] as List? ?? []),
      isCommunity: json['isCommunity'] as bool? ??
          ((json['id'] as String? ?? '').startsWith('community:') ||
              json['category'] == 'Community'),
      ratingCount: json['ratingCount'] as int? ?? 1,
      ratingSum: (json['ratingSum'] as num?)?.toDouble() ??
          (double.tryParse(json['rating'] as String? ?? '5.0') ?? 5.0),
      authorName: json['authorName'] as String? ?? 'Community Chef',
      postedDate: json['postedDate'] as String? ?? 'Today',
      isAdapted: rawIsAdapted,
      sourceName: rawSourceName ?? (rawSourceUrl != null ? 'Original Author' : null),
      sourceUrl: rawSourceUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': name,
        'name': name,
        'category': category,
        'image': image,
        'imageUrl': image,
        'rating': rating,
        'description': description,
        'chefNotes': description,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        'time': time,
        'servings': servings,
        'ingredientItems': ingredientItems.map((e) => e.toJson()).toList(),
        'ingredients': ingredients,
        'instructions': instructions.map((e) => e.toJson()).toList(),
        'steps': steps,
        'stepImages': stepImages,
        'notices': notices,
        'sourceUrl': sourceUrl,
        'isCommunity': isCommunity,
        'ratingCount': ratingCount,
        'ratingSum': ratingSum,
        'authorName': authorName,
        'postedDate': postedDate,
        'isAdapted': isAdapted,
        'sourceName': sourceName,
      };

  String get title => name;
  String get imageUrl => image;
  String get chefNotes => description;

  String imageForStep(int index) =>
      index < stepImages.length && stepImages[index].isNotEmpty
          ? stepImages[index]
          : sourceUrl == null
              ? image
              : '';

  Recipe copyWith({
    String? name,
    String? category,
    String? image,
    String? rating,
    String? description,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? time,
    int? servings,
    List<IngredientItem>? ingredientItems,
    List<InstructionStep>? instructions,
    List<List<String>>? ingredients,
    List<String>? steps,
    bool? isCommunity,
    int? ratingCount,
    double? ratingSum,
    String? authorName,
    String? postedDate,
    bool? isAdapted,
    String? sourceName,
    String? sourceUrl,
  }) {
    return Recipe(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      // CRITICAL PRESERVATION: If image parameter is null or empty, preserve existing image!
      image: (image != null && image.trim().isNotEmpty) ? image : this.image,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      time: time ?? this.time,
      servings: servings ?? this.servings,
      ingredientItems: ingredientItems ?? this.ingredientItems,
      instructions: instructions ?? this.instructions,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      stepImages: stepImages,
      notices: notices,
      isCommunity: isCommunity ?? this.isCommunity,
      ratingCount: ratingCount ?? this.ratingCount,
      ratingSum: ratingSum ?? this.ratingSum,
      authorName: authorName ?? this.authorName,
      postedDate: postedDate ?? this.postedDate,
      isAdapted: isAdapted ?? this.isAdapted,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  String get timeLabel => time > 0 ? '$time min' : 'Time not listed';
  String get ratingLabel => rating.isEmpty ? 'Imported' : '★ $rating';
}

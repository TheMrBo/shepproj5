class Recipe {
  final String? sourceUrl;
  final String id, name, category, image, rating, description;
  final int time;
  final List<List<String>> ingredients;
  final List<String> steps;
  final List<String> stepImages;
  final List<String> notices;
  final bool isCommunity;
  final int ratingCount;
  final double ratingSum;

  Recipe.fromJson(Map<String, dynamic> json)
    : sourceUrl = json['sourceUrl'] as String?,
      id = json['id'] as String,
      name = json['name'] as String,
      category = json['category'] as String,
      image = json['sourceUrl'] != null
          ? (json['image'] as String? ?? '')
          : (json['image'] as String? ?? '').startsWith('assets/')
          ? json['image'] as String
          : 'assets/${json['image'] ?? 'ramen'}.webp',
      rating = json['rating'] as String? ?? '5.0',
      description = json['description'] as String? ?? '',
      time = json['time'] as int? ?? 0,
      ingredients = (json['ingredients'] as List? ?? [])
          .map((e) => List<String>.from(e as List))
          .toList(),
      steps = List<String>.from(json['steps'] as List? ?? []),
      stepImages = List<String>.from(json['stepImages'] as List? ?? []),
      notices = List<String>.from(json['notices'] as List? ?? []),
      isCommunity = json['isCommunity'] as bool? ??
          ((json['id'] as String? ?? '').startsWith('community:') ||
              json['category'] == 'Community'),
      ratingCount = json['ratingCount'] as int? ?? 1,
      ratingSum = (json['ratingSum'] as num?)?.toDouble() ??
          (double.tryParse(json['rating'] as String? ?? '5.0') ?? 5.0);

  Recipe copyWith({
    String? rating,
    int? ratingCount,
    double? ratingSum,
  }) {
    final map = toJson();
    if (rating != null) map['rating'] = rating;
    if (ratingCount != null) map['ratingCount'] = ratingCount;
    if (ratingSum != null) map['ratingSum'] = ratingSum;
    return Recipe.fromJson(map);
  }

  String imageForStep(int index) =>
      index < stepImages.length && stepImages[index].isNotEmpty
      ? stepImages[index]
      : sourceUrl == null
      ? image
      : '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'image': image,
    'rating': rating,
    'description': description,
    'time': time,
    'ingredients': ingredients,
    'steps': steps,
    'stepImages': stepImages,
    'notices': notices,
    'sourceUrl': sourceUrl,
    'isCommunity': isCommunity,
    'ratingCount': ratingCount,
    'ratingSum': ratingSum,
  };
  String get timeLabel => time > 0 ? '$time min' : 'Time not listed';
  String get ratingLabel => rating.isEmpty ? 'Imported' : '★ $rating';
}

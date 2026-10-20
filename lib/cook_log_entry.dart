class CookLogEntry {
  final String recipeId;
  final DateTime cookedAt;

  CookLogEntry({required this.recipeId, required this.cookedAt});

  CookLogEntry.fromJson(Map<String, dynamic> json)
    : recipeId = json['recipeId'] as String,
      cookedAt = DateTime.parse(json['cookedAt'] as String);

  Map<String, dynamic> toJson() => {
    'recipeId': recipeId,
    'cookedAt': cookedAt.toIso8601String(),
  };
}

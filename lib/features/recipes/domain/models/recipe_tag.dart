class RecipeTag {
  final String id;
  final String name;
  final String category; // 'cuisine', 'meal_type', 'diet', 'method', 'general'

  const RecipeTag({
    required this.id,
    required this.name,
    this.category = 'general',
  });

  RecipeTag copyWith({
    String? id,
    String? name,
    String? category,
  }) {
    return RecipeTag(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
      };

  factory RecipeTag.fromJson(Map<String, dynamic> json) {
    return RecipeTag(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'general',
    );
  }
}

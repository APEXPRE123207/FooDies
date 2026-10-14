import 'ingredient.dart';
import 'nutrition_info.dart';
import 'recipe_step.dart';
import 'recipe_tag.dart';

class Recipe {
  final String id;
  final String title;
  final String? description;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? sourceCaption;
  final String? transcript;
  final String? originalLanguage;
  final String? imagePath;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  final int servingCount;
  final NutritionInfo nutrition;
  final bool isFavorite;
  final double? extractionConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final List<RecipeTag> tags;

  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.sourceUrl,
    this.sourcePlatform,
    this.sourceCaption,
    this.transcript,
    this.originalLanguage,
    this.imagePath,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.servingCount = 2,
    this.nutrition = const NutritionInfo(),
    this.isFavorite = false,
    this.extractionConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
  });

  int? get effectiveTotalTime {
    if (totalTimeMinutes != null && totalTimeMinutes! > 0) {
      return totalTimeMinutes;
    }
    final prep = prepTimeMinutes ?? 0;
    final cook = cookTimeMinutes ?? 0;
    final sum = prep + cook;
    return sum > 0 ? sum : null;
  }

  String get formattedTime {
    final time = effectiveTotalTime;
    if (time == null || time <= 0) return 'Quick cook';
    if (time < 60) return '$time mins';
    final hours = time ~/ 60;
    final mins = time % 60;
    return mins > 0 ? '$hours hr $mins m' : '$hours hr';
  }

  List<Ingredient> getScaledIngredients(int targetServings) {
    if (servingCount <= 0 || targetServings == servingCount) {
      return ingredients;
    }
    final factor = targetServings / servingCount;
    return ingredients.map((i) => i.scale(factor)).toList();
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? sourceUrl,
    String? sourcePlatform,
    String? sourceCaption,
    String? transcript,
    String? originalLanguage,
    String? imagePath,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? totalTimeMinutes,
    int? servingCount,
    NutritionInfo? nutrition,
    bool? isFavorite,
    double? extractionConfidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    List<RecipeTag>? tags,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      sourceCaption: sourceCaption ?? this.sourceCaption,
      transcript: transcript ?? this.transcript,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      imagePath: imagePath ?? this.imagePath,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      servingCount: servingCount ?? this.servingCount,
      nutrition: nutrition ?? this.nutrition,
      isFavorite: isFavorite ?? this.isFavorite,
      extractionConfidence: extractionConfidence ?? this.extractionConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sourceUrl': sourceUrl,
        'sourcePlatform': sourcePlatform,
        'sourceCaption': sourceCaption,
        'transcript': transcript,
        'originalLanguage': originalLanguage,
        'imagePath': imagePath,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        'totalTimeMinutes': totalTimeMinutes,
        'servingCount': servingCount,
        'nutrition': nutrition.toJson(),
        'isFavorite': isFavorite,
        'extractionConfidence': extractionConfidence,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'tags': tags.map((t) => t.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final recipeId = json['id'] as String? ?? '';
    return Recipe(
      id: recipeId,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      sourcePlatform: json['sourcePlatform'] as String?,
      sourceCaption: json['sourceCaption'] as String?,
      transcript: json['transcript'] as String?,
      originalLanguage: json['originalLanguage'] as String?,
      imagePath: json['imagePath'] as String?,
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      cookTimeMinutes: json['cookTimeMinutes'] as int?,
      totalTimeMinutes: json['totalTimeMinutes'] as int?,
      servingCount: json['servingCount'] as int? ?? 2,
      nutrition: json['nutrition'] is Map
          ? NutritionInfo.fromJson(Map<String, dynamic>.from(json['nutrition'] as Map))
          : const NutritionInfo(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      extractionConfidence: (json['extractionConfidence'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return Ingredient.fromJson(e);
                } else if (e is Map) {
                  return Ingredient.fromJson(Map<String, dynamic>.from(e));
                } else {
                  return Ingredient(id: '', recipeId: recipeId, name: e.toString());
                }
              })
              .toList() ??
          [],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return RecipeStep.fromJson(e);
                } else if (e is Map) {
                  return RecipeStep.fromJson(Map<String, dynamic>.from(e));
                } else {
                  return RecipeStep(id: '', recipeId: recipeId, stepNumber: 1, instruction: e.toString());
                }
              })
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return RecipeTag.fromJson(e);
                } else if (e is Map) {
                  return RecipeTag.fromJson(Map<String, dynamic>.from(e));
                } else {
                  return RecipeTag(id: '', name: e.toString());
                }
              })
              .toList() ??
          [],
    );
  }
}

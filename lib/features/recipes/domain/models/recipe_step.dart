class RecipeStep {
  final String id;
  final String recipeId;
  final int stepNumber;
  final String instruction;
  final int? durationMinutes;

  const RecipeStep({
    required this.id,
    required this.recipeId,
    required this.stepNumber,
    required this.instruction,
    this.durationMinutes,
  });

  RecipeStep copyWith({
    String? id,
    String? recipeId,
    int? stepNumber,
    String? instruction,
    int? durationMinutes,
  }) {
    return RecipeStep(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      stepNumber: stepNumber ?? this.stepNumber,
      instruction: instruction ?? this.instruction,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'stepNumber': stepNumber,
        'instruction': instruction,
        'durationMinutes': durationMinutes,
      };

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String? ?? '',
      stepNumber: json['stepNumber'] as int,
      instruction: json['instruction'] as String,
      durationMinutes: json['durationMinutes'] as int?,
    );
  }
}

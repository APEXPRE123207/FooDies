class NutritionInfo {
  final double? calories;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  /// Provenance / method: 'creator', 'estimated', 'unavailable'
  final String method;
  /// Confidence: 'high', 'medium', 'low', or null
  final String? confidence;

  const NutritionInfo({
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.method = 'unavailable',
    this.confidence,
  });

  bool get hasValues =>
      calories != null ||
      proteinGrams != null ||
      carbsGrams != null ||
      fatGrams != null;

  NutritionInfo copyWith({
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? method,
    String? confidence,
  }) {
    return NutritionInfo(
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      method: method ?? this.method,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'method': method,
        'confidence': confidence,
      };

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] as num?)?.toDouble(),
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble(),
      carbsGrams: (json['carbsGrams'] as num?)?.toDouble(),
      fatGrams: (json['fatGrams'] as num?)?.toDouble(),
      method: json['method'] as String? ?? 'unavailable',
      confidence: json['confidence'] as String?,
    );
  }
}

class Ingredient {
  final String id;
  final String recipeId;
  final String name;
  final double? quantity;
  final String? unit;
  final String? notes;
  final bool isOptional;
  final bool isEstimated;
  final int sortOrder;

  const Ingredient({
    required this.id,
    required this.recipeId,
    required this.name,
    this.quantity,
    this.unit,
    this.notes,
    this.isOptional = false,
    this.isEstimated = false,
    this.sortOrder = 0,
  });

  /// Scale ingredient quantity by serving factor
  Ingredient scale(double factor) {
    if (quantity == null) return this;
    final scaled = (quantity! * factor);
    // Round to 2 decimal places to avoid IEEE 754 precision issues
    final rounded = (scaled * 100).roundToDouble() / 100;
    return copyWith(quantity: rounded);
  }

  String get displayQuantity {
    if (quantity == null) return '';
    final prefix = isEstimated ? '~' : '';
    if (quantity! % 1 == 0) {
      return '$prefix${quantity!.toInt()}';
    }
    // Simple fractions for clean cooking view
    final whole = quantity!.toInt();
    final remainder = quantity! - whole;
    if ((remainder - 0.5).abs() < 0.05) {
      return '$prefix${whole > 0 ? '$whole ½' : '½'}';
    } else if ((remainder - 0.25).abs() < 0.05) {
      return '$prefix${whole > 0 ? '$whole ¼' : '¼'}';
    } else if ((remainder - 0.75).abs() < 0.05) {
      return '$prefix${whole > 0 ? '$whole ¾' : '¾'}';
    } else if ((remainder - 0.33).abs() < 0.05) {
      return '$prefix${whole > 0 ? '$whole ⅓' : '⅓'}';
    } else if ((remainder - 0.67).abs() < 0.05) {
      return '$prefix${whole > 0 ? '$whole ⅔' : '⅔'}';
    }
    return '$prefix${quantity!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}';
  }

  /// Checks if this ingredient has a saved alternative in its notes (e.g. "or Firm Tofu")
  bool get hasAlternative {
    if (notes == null || notes!.trim().isEmpty) return false;
    return RegExp(r'\bor\s+[^,)]+', caseSensitive: false).hasMatch(notes!);
  }

  /// Extracts the saved alternative name if present (e.g. "Firm Tofu")
  String? get alternativeName {
    if (notes == null) return null;
    final match = RegExp(r'\bor\s+([^,)]+)', caseSensitive: false).firstMatch(notes!);
    return match?.group(1)?.trim();
  }

  /// Returns the base notes excluding any bracketed alternative
  String? get baseNotes {
    if (notes == null) return null;
    final cleaned = notes!
        .replaceAll(RegExp(r'\s*\(?or\s+[^)]+\)?', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*$'), '')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String get fullDisplayText {
    final parts = <String>[];
    final qty = displayQuantity;
    if (qty.isNotEmpty) parts.add(qty);
    if (unit != null && unit!.trim().isNotEmpty) parts.add(unit!.trim());
    parts.add(name);
    if (notes != null && notes!.trim().isNotEmpty) parts.add('(${notes!.trim()})');
    if (isOptional) parts.add('(optional)');
    return parts.join(' ');
  }

  Ingredient copyWith({
    String? id,
    String? recipeId,
    String? name,
    double? quantity,
    String? unit,
    String? notes,
    bool? isOptional,
    bool? isEstimated,
    int? sortOrder,
  }) {
    return Ingredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      isOptional: isOptional ?? this.isOptional,
      isEstimated: isEstimated ?? this.isEstimated,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
        'isOptional': isOptional,
        'isEstimated': isEstimated,
        'sortOrder': sortOrder,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String? ?? '',
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      notes: json['notes'] as String?,
      isOptional: json['isOptional'] as bool? ?? false,
      isEstimated: json['isEstimated'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class Ingredient {
  final String id;
  final String recipeId;
  final String name;
  final double? quantity;
  final String? unit;
  final String? notes;
  final bool isOptional;
  final int sortOrder;

  const Ingredient({
    required this.id,
    required this.recipeId,
    required this.name,
    this.quantity,
    this.unit,
    this.notes,
    this.isOptional = false,
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
    if (quantity! % 1 == 0) {
      return quantity!.toInt().toString();
    }
    // Simple fractions for clean cooking view
    final whole = quantity!.toInt();
    final remainder = quantity! - whole;
    if ((remainder - 0.5).abs() < 0.05) {
      return whole > 0 ? '$whole ½' : '½';
    } else if ((remainder - 0.25).abs() < 0.05) {
      return whole > 0 ? '$whole ¼' : '¼';
    } else if ((remainder - 0.75).abs() < 0.05) {
      return whole > 0 ? '$whole ¾' : '¾';
    } else if ((remainder - 0.33).abs() < 0.05) {
      return whole > 0 ? '$whole ⅓' : '⅓';
    } else if ((remainder - 0.67).abs() < 0.05) {
      return whole > 0 ? '$whole ⅔' : '⅔';
    }
    return quantity!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
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
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

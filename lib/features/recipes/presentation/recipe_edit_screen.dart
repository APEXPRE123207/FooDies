import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/config/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../domain/models/ingredient.dart';
import '../domain/models/nutrition_info.dart';
import '../domain/models/recipe.dart';
import '../domain/models/recipe_step.dart';
import '../domain/models/recipe_tag.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const RecipeEditScreen({super.key, this.recipe});

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _servingsController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;
  late TextEditingController _tagInputController;

  late List<Ingredient> _ingredients;
  late List<RecipeStep> _steps;
  late List<RecipeTag> _tags;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleController = TextEditingController(text: r?.title ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _servingsController = TextEditingController(text: '${r?.servingCount ?? 2}');
    _prepTimeController = TextEditingController(text: r?.prepTimeMinutes != null ? '${r!.prepTimeMinutes}' : '');
    _cookTimeController = TextEditingController(text: r?.cookTimeMinutes != null ? '${r!.cookTimeMinutes}' : '');
    _tagInputController = TextEditingController();

    _ingredients = r != null ? List<Ingredient>.from(r.ingredients) : [];
    _steps = r != null ? List<RecipeStep>.from(r.steps) : [];
    _tags = r != null ? List<RecipeTag>.from(r.tags) : [];

    if (_ingredients.isEmpty) {
      _ingredients.add(const Ingredient(id: '', recipeId: '', name: ''));
    }
    if (_steps.isEmpty) {
      _steps.add(const RecipeStep(id: '', recipeId: '', stepNumber: 1, instruction: ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.recipe != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveRecipe,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title',
                hintText: 'e.g. Creamy Tuscan Garlic Chicken',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Short notes or origin...',
              ),
            ),
            const SizedBox(height: 16),

            // Servings, Prep Time, Cook Time
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      prefixIcon: Icon(Icons.people_outline, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prep (mins)',
                      prefixIcon: Icon(Icons.timer_outlined, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cook (mins)',
                      prefixIcon: Icon(Icons.microwave_outlined, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tags section
            _buildTagsSection(),
            const SizedBox(height: 24),

            // Ingredients section
            _buildIngredientsSection(),
            const SizedBox(height: 24),

            // Steps section
            _buildStepsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags & Categories',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map(
              (tag) => Chip(
                label: Text('#${tag.name}'),
                backgroundColor: AppColors.surfaceElevated,
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _tags.remove(tag));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputController,
                decoration: const InputDecoration(
                  hintText: 'Add tag (e.g. Italian, Quick, Dinner)',
                  isDense: true,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
              onPressed: _addTag,
            ),
          ],
        ),
      ],
    );
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty) {
      if (!_tags.any((t) => t.name.toLowerCase() == text.toLowerCase())) {
        setState(() {
          _tags.add(RecipeTag(id: const Uuid().v4(), name: text));
        });
      }
      _tagInputController.clear();
    }
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              onPressed: () {
                setState(() {
                  _ingredients.add(
                    Ingredient(
                      id: const Uuid().v4(),
                      recipeId: widget.recipe?.id ?? '',
                      name: '',
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ing = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: ing.quantity != null ? '${ing.quantity}' : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Qty', isDense: true),
                    onChanged: (val) {
                      _ingredients[index] = ing.copyWith(quantity: double.tryParse(val));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: ing.unit ?? '',
                    decoration: const InputDecoration(hintText: 'Unit', isDense: true),
                    onChanged: (val) {
                      _ingredients[index] = ing.copyWith(unit: val.trim().isNotEmpty ? val.trim() : null);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: ing.name,
                    decoration: const InputDecoration(hintText: 'Ingredient name', isDense: true),
                    onChanged: (val) {
                      _ingredients[index] = ing.copyWith(name: val.trim());
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                  onPressed: _ingredients.length > 1
                      ? () => setState(() => _ingredients.removeAt(index))
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cooking Steps',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Step'),
              onPressed: () {
                setState(() {
                  _steps.add(
                    RecipeStep(
                      id: const Uuid().v4(),
                      recipeId: widget.recipe?.id ?? '',
                      stepNumber: _steps.length + 1,
                      instruction: '',
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: step.instruction,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Describe this cooking step...', isDense: true),
                    onChanged: (val) {
                      _steps[index] = step.copyWith(instruction: val.trim(), stepNumber: index + 1);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                  onPressed: _steps.length > 1
                      ? () => setState(() => _steps.removeAt(index))
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final validIngredients = _ingredients.where((i) => i.name.trim().isNotEmpty).toList();
    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    final validSteps = _steps.where((s) => s.instruction.trim().isNotEmpty).toList();
    if (validSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one cooking step')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(recipeRepositoryProvider);
    final isEditing = widget.recipe != null;

    final recipeId = widget.recipe?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final recipeToSave = Recipe(
      id: recipeId,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      sourceUrl: widget.recipe?.sourceUrl,
      sourcePlatform: widget.recipe?.sourcePlatform,
      sourceCaption: widget.recipe?.sourceCaption,
      transcript: widget.recipe?.transcript,
      originalLanguage: widget.recipe?.originalLanguage ?? 'en',
      imagePath: widget.recipe?.imagePath,
      prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()),
      cookTimeMinutes: int.tryParse(_cookTimeController.text.trim()),
      servingCount: int.tryParse(_servingsController.text.trim()) ?? 2,
      nutrition: widget.recipe?.nutrition ?? const NutritionInfo(),
      isFavorite: widget.recipe?.isFavorite ?? false,
      extractionConfidence: widget.recipe?.extractionConfidence ?? 1.0,
      createdAt: widget.recipe?.createdAt ?? now,
      updatedAt: now,
      ingredients: validIngredients.map((i) => i.copyWith(recipeId: recipeId)).toList(),
      steps: validSteps.asMap().entries.map((e) => e.value.copyWith(recipeId: recipeId, stepNumber: e.key + 1)).toList(),
      tags: _tags,
    );

    try {
      if (isEditing) {
        await repo.updateRecipe(recipeToSave);
      } else {
        await repo.insertRecipe(recipeToSave);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

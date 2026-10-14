import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ai_substitution_service.dart';
import '../../domain/models/ingredient.dart';
import '../../domain/models/recipe.dart';

class IngredientSwapModal extends ConsumerStatefulWidget {
  final Recipe recipe;
  final Ingredient ingredient;

  const IngredientSwapModal({
    super.key,
    required this.recipe,
    required this.ingredient,
  });

  @override
  ConsumerState<IngredientSwapModal> createState() => _IngredientSwapModalState();
}

class _IngredientSwapModalState extends ConsumerState<IngredientSwapModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AI Recommendations State
  bool _isLoadingRecommendations = true;
  List<AiSubstitution> _substitutions = [];
  bool _isLiveAi = true;
  String? _statusMessage;

  // Custom Input State
  final _customInputController = TextEditingController();

  // Interactive Chef Q&A State
  final _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChefChatMessage> _chatMessages = [];
  bool _isChefThinking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customInputController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
      _statusMessage = null;
    });

    try {
      final service = ref.read(aiSubstitutionServiceProvider);
      final result = await service.getSubstitutions(
        recipe: widget.recipe,
        ingredient: widget.ingredient,
      );

      if (mounted) {
        setState(() {
          _substitutions = result.substitutions;
          _isLiveAi = result.isLiveAi;
          _statusMessage = result.message;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
          _statusMessage = 'Could not reach AI chef. Showing standard culinary options.';
        });
      }
    }
  }

  Future<void> _handleSaveAlternative(String alternativeName) async {
    HapticFeedback.mediumImpact();
    final cleanName = alternativeName.trim();
    if (cleanName.isEmpty) return;

    await ref.read(recipeRepositoryProvider).saveIngredientAlternative(
          recipeId: widget.recipe.id,
          ingredientId: widget.ingredient.id,
          alternativeName: cleanName,
        );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.badgeVegetarian, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added (or $cleanName) to recipe. Original "${widget.ingredient.name}" preserved!',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRemoveAlternative() async {
    HapticFeedback.selectionClick();
    await ref.read(recipeRepositoryProvider).removeIngredientAlternative(
          recipeId: widget.recipe.id,
          ingredientId: widget.ingredient.id,
        );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Row(
          children: [
            const Icon(Icons.restore, color: AppColors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reverted to original "${widget.ingredient.name}".',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendChefQuestion(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isChefThinking) return;

    HapticFeedback.selectionClick();
    _chatInputController.clear();

    final userMsg = ChefChatMessage(
      isUser: true,
      text: trimmed,
    );

    setState(() {
      _chatMessages.add(userMsg);
      _isChefThinking = true;
    });

    _scrollToBottom();

    try {
      final service = ref.read(aiSubstitutionServiceProvider);
      final reply = await service.askChefQuestion(
        recipe: widget.recipe,
        ingredient: widget.ingredient,
        question: trimmed,
        history: _chatMessages,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add(reply);
          _isChefThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(
            ChefChatMessage(
              isUser: false,
              text: 'Could not connect to AI Chef. Please check your network or Ollama settings.',
            ),
          );
          _isChefThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasActiveSwap = widget.ingredient.hasAlternative;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swap "${widget.ingredient.name}"',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'AI Culinary Sous-Chef • ${widget.recipe.title}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          // Active Saved Alternative Banner
          if (hasActiveSwap) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.saffronGold.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_added, color: AppColors.saffronGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        children: [
                          const TextSpan(text: 'Current: '),
                          TextSpan(
                            text: '(or ${widget.ingredient.alternativeName})',
                            style: const TextStyle(
                              color: AppColors.saffronGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: '\nOriginal recipe is intact',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Revert', style: TextStyle(fontSize: 12)),
                    onPressed: _handleRemoveAlternative,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Tab Selector: AI Recommendations vs Chef Q&A
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14),
                      SizedBox(width: 5),
                      Text('AI Swaps'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.question_answer_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('Ask Chef'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Recommendations Tab
                _buildRecommendationsTab(),

                // 2. Interactive Chef Q&A Tab
                _buildChefQnATab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_isLoadingRecommendations) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Chef is analyzing cooking steps & flavor chemistry...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Targeting: ${widget.ingredient.name}',
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _isLiveAi ? Icons.bolt : Icons.info_outline,
                  size: 15,
                  color: _isLiveAi ? AppColors.amber : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const Text(
          'Recommended by AI based on recipe techniques & ingredients:',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),

        ..._substitutions.map((sub) => _buildSubstitutionCard(sub)),

        const SizedBox(height: 16),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 14),

        // Custom Substitute Manual Input
        const Text(
          'Have something else in your pantry?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customInputController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter custom substitute...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () {
                final val = _customInputController.text.trim();
                if (val.isNotEmpty) {
                  _handleSaveAlternative(val);
                }
              },
              child: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSubstitutionCard(AiSubstitution sub) {
    final isSelected = widget.ingredient.alternativeName?.toLowerCase() == sub.name.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.saffronGold : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            sub.ratio,
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (sub.dietary != null && sub.dietary!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.badgeVegetarian.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sub.dietary!,
                              style: const TextStyle(
                                color: AppColors.badgeVegetarian,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppColors.saffronGold.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  foregroundColor: isSelected ? AppColors.saffronGold : AppColors.primary,
                  side: BorderSide(
                    color: isSelected ? AppColors.saffronGold : AppColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: Icon(
                  isSelected ? Icons.check : Icons.add,
                  size: 15,
                ),
                label: Text(
                  isSelected ? 'Active' : 'Keep',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () => _handleSaveAlternative(sub.name),
              ),
            ],
          ),
          if (sub.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sub.reason,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChefQnATab() {
    return Column(
      children: [
        // Quick Prompt Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickPromptChip('Can I omit this completely?'),
              const SizedBox(width: 6),
              _buildQuickPromptChip('Will it curdle if I boil it?'),
              const SizedBox(width: 6),
              _buildQuickPromptChip('Can I use low-fat?'),
              const SizedBox(width: 6),
              _buildQuickPromptChip('Will it change the taste?'),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Chat messages stream / list
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ask the AI Chef anything about this swap!',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The Chef will give you a clear YES or NO with practical culinary guidance tailored to this recipe\'s steps.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    return _buildChatBubble(msg);
                  },
                ),
        ),

        if (_isChefThinking) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Chef is testing the culinary physics...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        // Input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatInputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendChefQuestion,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask chef (e.g. "Can I use Greek yogurt?")...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(10),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              onPressed: () => _sendChefQuestion(_chatInputController.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPromptChip(String text) {
    return ActionChip(
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      label: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      onPressed: () => _sendChefQuestion(text),
    );
  }

  Widget _buildChatBubble(ChefChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14).copyWith(bottomRight: Radius.zero),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Chef response
    final isAffirmative = msg.isAffirmative;
    Color verdictBg = AppColors.surfaceElevated;
    Color verdictFg = AppColors.textPrimary;
    IconData verdictIcon = Icons.info_outline;

    if (isAffirmative == true) {
      verdictBg = AppColors.badgeVegetarian.withValues(alpha: 0.2);
      verdictFg = AppColors.badgeVegetarian;
      verdictIcon = Icons.check_circle;
    } else if (isAffirmative == false) {
      verdictBg = AppColors.macroCalories.withValues(alpha: 0.2);
      verdictFg = AppColors.macroCalories;
      verdictIcon = Icons.cancel;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 30),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14).copyWith(bottomLeft: Radius.zero),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.directVerdict != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: verdictBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(verdictIcon, size: 14, color: verdictFg),
                    const SizedBox(width: 4),
                    Text(
                      msg.directVerdict!,
                      style: TextStyle(
                        color: verdictFg,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              msg.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

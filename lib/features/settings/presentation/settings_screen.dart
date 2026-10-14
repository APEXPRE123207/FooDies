import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/features/onboarding/presentation/ai_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(allRecipesStreamProvider);
    final jobsAsync = ref.watch(importJobsStreamProvider);
    final keyConfiguredAsync = ref.watch(isApiKeyConfiguredProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. AI Integration Section
          _buildSectionHeader('AI EXTRACTION (OLLAMA CLOUD)'),
          Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
                  title: const Text('Ollama Cloud Configuration', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: keyConfiguredAsync.when(
                    data: (isSet) => Text(
                      isSet ? 'API Key Configured' : 'Missing API Key',
                      style: TextStyle(color: isSet ? AppColors.success : AppColors.error, fontSize: 12),
                    ),
                    loading: () => const Text('Checking...', style: TextStyle(fontSize: 12)),
                    error: (_, __) => const Text('Error', style: TextStyle(fontSize: 12)),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSetupScreen(isFromSettings: true)),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: AppColors.error),
                  title: const Text('Remove API Key', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                  subtitle: const Text('Clears credentials from device storage', style: TextStyle(fontSize: 12)),
                  onTap: () => _confirmClearKey(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Library & Storage Statistics
          _buildSectionHeader('LOCAL RECIPE LIBRARY'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'SAVED RECIPES',
                  recipesAsync.maybeWhen(
                    data: (r) => '${r.length}',
                    orElse: () => '--',
                  ),
                  Icons.restaurant,
                  AppColors.primary,
                ),
                Container(width: 1, height: 40, color: AppColors.border),
                _buildStat(
                  'FAVORITES',
                  recipesAsync.maybeWhen(
                    data: (r) => '${r.where((i) => i.isFavorite).length}',
                    orElse: () => '--',
                  ),
                  Icons.favorite,
                  AppColors.error,
                ),
                Container(width: 1, height: 40, color: AppColors.border),
                _buildStat(
                  'IMPORT JOBS',
                  jobsAsync.maybeWhen(
                    data: (j) => '${j.length}',
                    orElse: () => '--',
                  ),
                  Icons.sync,
                  AppColors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Security & Architecture Note
          _buildSectionHeader('SECURITY & ARCHITECTURE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Zero-Tracking & Local First',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Foodies stores all recipes, ingredients, and tags in an encrypted on-device SQLite database. No external accounts or cloud user profiles required. API keys are strictly kept in Android EncryptedSharedPreferences and are never sent to social platforms.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _confirmClearKey(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove API Key?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Your saved recipes will remain completely safe. You will need to re-enter your key to import new recipes using Ollama Cloud.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(secureStorageProvider).clearApiKey();
              ref.invalidate(isApiKeyConfiguredProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key removed.')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

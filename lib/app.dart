import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/ai_setup_screen.dart';
import 'features/recipes/presentation/home_feed_screen.dart';
import 'shared/widgets/app_logo.dart';

class FoodiesApp extends ConsumerWidget {
  const FoodiesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyConfiguredAsync = ref.watch(isApiKeyConfiguredProvider);

    return MaterialApp(
      title: 'Foodies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: keyConfiguredAsync.when(
        data: (isConfigured) {
          if (isConfigured) {
            return const HomeFeedScreen();
          } else {
            return const AiSetupScreen();
          }
        },
        loading: () => const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppLogo(size: 72, borderRadius: 22, padding: 8),
                SizedBox(height: 18),
                Text(
                  'FOODIES',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (_, __) => const HomeFeedScreen(), // Offline fallback guaranteed
      ),
    );
  }
}

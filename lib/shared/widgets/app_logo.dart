import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Standard branded Foodies logo with deep obsidian black background
/// and a rich golden-flame corner gradient border.
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final double padding;
  final bool showBorder;

  const AppLogo({
    super.key,
    this.size = 38,
    this.borderRadius = 12,
    this.padding = 3,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = size > 60 ? 2.5 : 1.5;

    if (!showBorder) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1015),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD54F), // Gold top-left
            Color(0xFFE65100), // Flame amber
            Color(0xFF261D16), // Dark obsidian corner transition
            Color(0xFFFFB300), // Gold bottom-right
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withOpacity(0.24),
            blurRadius: size * 0.25,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          if (size > 60)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(-2, -2),
            ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1015), // Deep obsidian black
          borderRadius: BorderRadius.circular((borderRadius - borderWidth).clamp(0.0, 100.0)),
        ),
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

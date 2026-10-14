import 'package:flutter/material.dart';

class AppColors {
  // Cinematic dark palette
  static const Color background = Color(0xFF090A0F);
  static const Color surface = Color(0xFF12141D);
  static const Color surfaceElevated = Color(0xFF1B1E2B);
  static const Color surfaceHighlight = Color(0xFF262A3C);

  // Warm Amber & Muted Orange Accents
  static const Color primary = Color(0xFFFF6E2E);
  static const Color primaryLight = Color(0xFFFF8B52);
  static const Color primaryDark = Color(0xFFD94E0F);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberMuted = Color(0xFFD97706);

  // Neutral tones
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0x1AFFFFFF); // subtle 10% white
  static const Color borderLight = Color(0x2EFFFFFF); // 18% white

  // Status & Badges
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x80000000),
      Color(0xEE090A0F),
    ],
    stops: [0.3, 0.65, 1.0],
  );

  static const LinearGradient flameGradient = LinearGradient(
    colors: [Color(0xFFFF6E2E), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

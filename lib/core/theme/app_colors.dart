import 'package:flutter/material.dart';

class AppColors {
  // Warm Culinary Dark Palette (Espresso & Obsidian)
  static const Color background = Color(0xFF0C0A09); // Warm Obsidian / Stone 950
  static const Color surface = Color(0xFF161412); // Cast Iron / Espresso
  static const Color surfaceElevated = Color(0xFF1F1C19); // Smoked Charcoal
  static const Color surfaceHighlight = Color(0xFF292524); // Warm Graphite
  static const Color surfaceGlass = Color(0xD91F1C19); // 85% Smoked Charcoal glass

  // Warm Culinary Accents
  static const Color primary = Color(0xFFFF6E2E); // Flame Orange
  static const Color primaryLight = Color(0xFFFF8B52);
  static const Color primaryDark = Color(0xFFD94E0F);
  static const Color amber = Color(0xFFFBBF24); // Saffron Gold
  static const Color saffronGold = Color(0xFFFBBF24);
  static const Color amberMuted = Color(0xFFD97706);

  // Warm Neutral Tones (Stone)
  static const Color textPrimary = Color(0xFFFAFAF9); // Warm Bone White
  static const Color textSecondary = Color(0xFFA8A29E); // Warm Stone Grey
  static const Color textMuted = Color(0xFF78716C); // Muted Coffee Dust
  static const Color border = Color(0xFF292524); // Warm Graphite border
  static const Color borderLight = Color(0xFF3D3835); // Subtle separator

  // Semantic Colors for Macros & Fitness Badges
  static const Color macroProtein = Color(0xFF10B981); // Emerald Mint (Muscle Gain)
  static const Color macroProteinSky = Color(0xFF38BDF8); // Electric Sky
  static const Color macroCalories = Color(0xFFFF6E2E); // Flame Orange (Energy / Fat Loss)
  static const Color macroCarbs = Color(0xFFF59E0B); // Amber Gold (Pre-Workout Energy)
  static const Color macroFats = Color(0xFFA855F7); // Rich Plum (Keto / Healthy Fats)
  static const Color badgeVegetarian = Color(0xFF22C55E); // Fresh Basil Green
  static const Color badgeQuick = Color(0xFFFBBF24); // Saffron Gold (Quick Cook)

  // System Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF38BDF8);

  // Gradients
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x800C0A09),
      Color(0xF50C0A09),
    ],
    stops: [0.25, 0.65, 1.0],
  );

  static const LinearGradient flameGradient = LinearGradient(
    colors: [Color(0xFFFF6E2E), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

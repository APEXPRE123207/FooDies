import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RecipeCardImage extends StatelessWidget {
  final String? imagePath;
  final String title;
  final String? category;
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const RecipeCardImage({
    super.key,
    required this.imagePath,
    required this.title,
    this.category,
    this.height = double.infinity,
    this.width = double.infinity,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

    Widget imageWidget;
    if (imagePath != null && imagePath!.isNotEmpty) {
      if (imagePath!.startsWith('http://') || imagePath!.startsWith('https://')) {
        imageWidget = Image.network(
          imagePath!,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDesignedPlaceholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildDesignedPlaceholder(isLoading: true);
          },
        );
      } else {
        final file = File(imagePath!);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDesignedPlaceholder(),
          );
        } else {
          imageWidget = _buildDesignedPlaceholder();
        }
      }
    } else {
      imageWidget = _buildDesignedPlaceholder();
    }

    return ClipRRect(
      borderRadius: radius,
      child: imageWidget,
    );
  }

  Widget _buildDesignedPlaceholder({bool isLoading = false}) {
    // Generate harmonious aesthetic background based on recipe title hash
    final hash = title.hashCode.abs();
    final gradientIndex = hash % 4;

    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF1E1428), Color(0xFF2E1924), Color(0xFF141724)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF1B2321), Color(0xFF1A1F2B), Color(0xFF281D14)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      const LinearGradient(
        colors: [Color(0xFF2A1C14), Color(0xFF1D1B28), Color(0xFF151922)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      const LinearGradient(
        colors: [Color(0xFF24151B), Color(0xFF142028), Color(0xFF1F1D15)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    ];

    IconData dishIcon = Icons.restaurant_menu;
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('pasta') || lowerTitle.contains('spaghetti') || lowerTitle.contains('noodle')) {
      dishIcon = Icons.ramen_dining;
    } else if (lowerTitle.contains('pizza') || lowerTitle.contains('bake') || lowerTitle.contains('bread')) {
      dishIcon = Icons.local_pizza;
    } else if (lowerTitle.contains('burger') || lowerTitle.contains('sandwich')) {
      dishIcon = Icons.lunch_dining;
    } else if (lowerTitle.contains('soup') || lowerTitle.contains('stew') || lowerTitle.contains('curry')) {
      dishIcon = Icons.soup_kitchen;
    } else if (lowerTitle.contains('salad') || lowerTitle.contains('green')) {
      dishIcon = Icons.eco;
    } else if (lowerTitle.contains('cake') || lowerTitle.contains('dessert') || lowerTitle.contains('cookie')) {
      dishIcon = Icons.cake;
    } else if (lowerTitle.contains('coffee') || lowerTitle.contains('tea') || lowerTitle.contains('drink')) {
      dishIcon = Icons.local_cafe;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 140 || constraints.maxWidth < 140;
        final circleSize = isCompact ? 44.0 : 72.0;
        final iconSize = isCompact ? 22.0 : 34.0;

        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            gradient: gradients[gradientIndex],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ambient ember glow
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: isCompact ? 80 : 140,
                  height: isCompact ? 80 : 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: isCompact ? 90 : 160,
                  height: isCompact ? 90 : 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.amber.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Center Icon & Title initials
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.35),
                        width: isCompact ? 1.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: isCompact ? 10 : 20,
                          spreadRadius: isCompact ? 1 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? SizedBox(
                              width: isCompact ? 16 : 24,
                              height: isCompact ? 16 : 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(
                              dishIcon,
                              size: iconSize,
                              color: AppColors.primaryLight,
                            ),
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: Text(
                        category?.toUpperCase() ?? 'FOODIES RECIPE',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

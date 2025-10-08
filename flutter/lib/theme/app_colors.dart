import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryCyan = Color(0xFF5CE5E5);
  static const Color primaryCyanDark = Color(0xFF4DD4D4);

  // Background Colors
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color backgroundDarker = Color(0xFF0F0F0F);
  static const Color cardElevated = Color(0xFF252525);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8B8);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textGreeting = Color(0xFFC0C0C0);
  // Surface Colors
  static final Color surfaceCard = Colors.white.withOpacity(0.05);
  static final Color surfaceCardHover = Colors.white.withOpacity(0.08);
  static final Color surfaceOverlay = Colors.black.withOpacity(0.6);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF2196F3);
  // Gradient Overlays
  static final LinearGradient imageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.6),
    ],
    stops: const [0.0, 1.0],
  );

  static final LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      surfaceCard,
      cardElevated,
    ],
  );
}

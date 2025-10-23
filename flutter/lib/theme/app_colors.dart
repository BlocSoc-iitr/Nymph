import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color accentColor = Color(0xFF00D4FF);
  static const Color accentColorDark = Color(0xFF00B8D4);

  // Background Colors
  static const Color backgroundColor = Color(0xFF050505); // Darker background
  static const Color cardBackgroundColor = Color(0xFF1A1A1A);
  static const Color cardElevated = Color(0xFF252525);

  // Text Colors
  static const Color textPrimaryColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF888888);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textGreeting = Color(0xFFC0C0C0);

  // Border Colors
  static const Color borderColor = Color(0xFF333333);

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
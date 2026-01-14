import 'package:flutter/material.dart';

/// Consistent spacing values throughout the app
/// Based on an 8px grid system
class AppSpacing {
  AppSpacing._();

  // Base unit
  static const double unit = 8.0;

  // Spacing scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: md,
  );

  // Component spacing
  static const double buttonPadding = 20.0;
  static const double cardPadding = 16.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusRound = 100.0;

  // Minimum tap target size (accessibility)
  static const double minTapTarget = 48.0;
  static const double largeTapTarget = 64.0;

  // Game-specific
  static const double gameButtonSize = 120.0;
  static const double progressDotSize = 12.0;
  static const double progressDotSpacing = 8.0;
}

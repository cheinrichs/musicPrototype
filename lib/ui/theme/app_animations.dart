import 'package:flutter/material.dart';

/// Animation constants for the "squishy" feel
class AppAnimations {
  AppAnimations._();

  // Durations
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration feedback = Duration(milliseconds: 1200);

  // Button press animation
  static const Duration buttonPressDown = Duration(milliseconds: 80);
  static const Duration buttonPressUp = Duration(milliseconds: 250);
  static const double buttonPressScale = 0.92;
  static const double buttonBounceScale = 1.05;

  // Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve squishCurve = Curves.easeOutBack;

  // Screen transitions
  static const Duration screenTransition = Duration(milliseconds: 300);
  static const Curve screenTransitionCurve = Curves.easeInOutCubic;

  // Feedback animations
  static const Duration correctFeedback = Duration(milliseconds: 400);
  static const Duration incorrectFeedback = Duration(milliseconds: 300);
  static const double shakeOffset = 10.0;

  // Progress dot animation
  static const Duration dotFill = Duration(milliseconds: 200);

  // Celebration
  static const Duration confettiBurst = Duration(milliseconds: 3000);
  static const Duration characterBounce = Duration(milliseconds: 500);
}

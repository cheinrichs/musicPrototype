import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography styles for the ear training app.
///
/// Ported from the Lumi design system: Fraunces (a warm serif) for
/// display/heading text, Nunito for everything else — matching
/// `--font-display` / `--font-ui` in SongStone-UI-Kit/UI/kit.css.
/// Large, readable text for kids with minimal reading.
class AppTypography {
  AppTypography._();

  // Headings — Fraunces, big and warm
  static TextStyle get heading1 => GoogleFonts.fraunces(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.015,
  );

  static TextStyle get heading2 => GoogleFonts.fraunces(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.015,
  );

  static TextStyle get heading3 => GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Italic serif subtitle, matching `.kit-sub` in kit.css
  static TextStyle get headingSubtitle => GoogleFonts.fraunces(
    fontSize: 19,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Body text — Nunito
  static TextStyle get bodyLarge => GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get bodyMedium => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Button text — Nunito, extra bold like the CSS .c-action/.c-cta labels
  static TextStyle get buttonLarge => GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnPrimary,
    height: 1.2,
  );

  static TextStyle get buttonMedium => GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnPrimary,
    height: 1.2,
  );

  // Labels — matches the all-caps eyebrow/tag treatment in kit.css
  static TextStyle get label => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.textSecondary,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // Numbers (for scores, streaks)
  static TextStyle get number => GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    height: 1.0,
  );
}

import 'package:flutter/material.dart';

/// Color palette for the ear training app.
///
/// Ported from the "Lumi" design system (see SongStone-UI-Kit/UI/kit.css) —
/// a warm, painterly parchment palette used in the Unity version of this
/// game. Raw tokens below match the CSS custom properties 1:1; the
/// semantic aliases further down (primary, textPrimary, etc.) point at
/// those tokens so existing call sites across the app pick up the new
/// look without needing to be rewritten one by one.
class AppColors {
  AppColors._();

  // ---- Canonical Lumi palette (named on the character sheets) ----
  static const Color ink = Color(0xFF2B2620);
  static const Color warmGray = Color(0xFF6E665A);
  static const Color ivory = Color(0xFFF3E9CE);
  static const Color ivoryDeep = Color(0xFFE7D7B0);
  static const Color gold = Color(0xFFD9A23B);
  static const Color goldDeep = Color(0xFFB47E22);
  static const Color sage = Color(0xFF8CA86E);
  static const Color forest = Color(0xFF4A6B3A);
  static const Color sky = Color(0xFF7FA8C9);
  static const Color skyDeep = Color(0xFF5B86AB);
  static const Color lavender = Color(0xFFA795C4);
  static const Color plum = Color(0xFF7E6597);
  static const Color fox = Color(0xFFD98A4E);
  static const Color rose = Color(0xFFC77E84);

  // ---- Pitch / note color system (low -> high) ----
  static const Color note1 = Color(0xFF5B8CC4); // low — blue
  static const Color note2 = Color(0xFF6FA86A); // green
  static const Color note3 = Color(0xFFE3B43E); // yellow
  static const Color note4 = Color(0xFFE08A45); // orange
  static const Color note5 = Color(0xFFD2603F); // high — red

  // ---- Surfaces ----
  static const Color paper = Color(0xFFEDE0C0);
  static const Color card = Color(0xFFF6EDD6);
  static const Color cardEdge = Color(0x4D966E3C); // rgba(150,110,60,0.30)
  static const Color night = Color(0xFF2C3357);
  static const Color night2 = Color(0xFF3C436B);

  // ---- Semantic aliases (existing call sites use these names) ----

  // Primary = the sage/forest green action family (c-cta, c-action.green)
  static const Color primary = sage;
  static const Color primaryLight = Color(0xFFA9C088);
  static const Color primaryDark = forest;

  // Secondary = the sky blue action family (c-action.blue)
  static const Color secondary = sky;
  static const Color secondaryLight = Color(0xFFAFC9DE);

  // Feedback colors — incorrect uses rose, not a harsh red, per the
  // "gentle, quick to recover" design principle in CLAUDE.md.
  static const Color correct = sage;
  static const Color correctLight = Color(0xFFB9CDA0);
  static const Color incorrect = rose;
  static const Color incorrectLight = Color(0xFFDDB0B4);

  // Background colors
  static const Color background = ivory;
  static const Color surface = card;
  static const Color surfaceVariant = ivoryDeep;

  // Text colors
  static const Color textPrimary = ink;
  static const Color textSecondary = warmGray;
  static const Color textOnPrimary = ivory;

  // Game button colors — mapped onto the pitch/note color system since
  // these are literally used for the High vs Low game (low=blue, high=red)
  static const Color higherButton = note5;
  static const Color lowerButton = note1;

  // Reward/celebration colors
  static const Color silver = Color(0xFFC7BEA8);
  static const Color bronze = Color(0xFFAD8150);

  // Shadow color — warm ink tint rather than flat black, matching the
  // painterly drop shadows used throughout kit.css
  static const Color shadow = Color(0x1F2B2620);

  // ---- Gradients (used by the redesigned buttons/cards) ----
  static const LinearGradient buttonGreenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF88A861), Color(0xFF6A8A48)],
  );
  static const Color buttonGreenShadow = Color(0xFF4E6A34);

  static const LinearGradient buttonBlueGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6E9DBE), Color(0xFF517E9E)],
  );
  static const Color buttonBlueShadow = Color(0xFF3E647E);

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF88A861), Color(0xFF5E7E3E)],
  );
  static const Color ctaShadow = Color(0xFF3C5428);

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7EFD9), Color(0xFFEFE3C4)],
  );
  static const Color cardShadow = Color(0x40966E3C); // rgba(150,110,60,0.25)
}

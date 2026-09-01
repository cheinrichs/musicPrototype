import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../ui/theme/theme.dart';
import 'router.dart';
import 'state/dev_settings_state.dart';
import 'state/progress_state.dart';
import 'state/skill_state.dart';

/// Main app widget
class EarTrainerApp extends StatelessWidget {
  const EarTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressState()..load()),
        ChangeNotifierProvider(create: (_) => SkillState()..load()),
        ChangeNotifierProvider(create: (_) => DevSettingsState()),
      ],
      child: MaterialApp.router(
        title: 'Ear Trainer',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: appRouter,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Base text theme comes from Nunito (the Lumi "UI" font); individual
      // styles below override specific roles with Fraunces (the "display"
      // font) where the design calls for it. AppTypography styles are no
      // longer `const` (GoogleFonts.* isn't a const constructor), so this
      // whole ThemeData/TextTheme build is non-const too.
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        displayLarge: AppTypography.heading1,
        displayMedium: AppTypography.heading2,
        displaySmall: AppTypography.heading3,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.buttonLarge,
        labelMedium: AppTypography.buttonMedium,
        labelSmall: AppTypography.label,
      ),
    );
  }
}

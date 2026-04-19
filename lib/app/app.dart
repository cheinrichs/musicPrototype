import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/theme.dart';
import 'router.dart';
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
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
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

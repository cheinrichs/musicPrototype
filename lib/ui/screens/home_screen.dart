import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/progress_state.dart';
import '../components/game_card.dart';
import '../components/squishy_button.dart';
import '../theme/theme.dart';

/// Home screen with game selection and progress display
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _buildGameSelection(context)),
              const SizedBox(height: AppSpacing.lg),
              _buildPlayButton(context),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<ProgressState>(
      builder: (context, progress, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // App title
            Text(
                  'Ear Training Games',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.primary,
                  ),
                )
                .animate()
                .fade(duration: AppAnimations.medium)
                .slideX(begin: -0.1, end: 0, duration: AppAnimations.medium),
            // Streak badge
            if (progress.currentStreak > 0)
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusRound,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 20,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${progress.currentStreak}',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fade(duration: AppAnimations.medium)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: AppAnimations.medium,
                    curve: AppAnimations.bounceCurve,
                  ),
          ],
        );
      },
    );
  }

  Widget _buildGameSelection(BuildContext context) {
    return Column(
      children: [
        Text('Choose a game', style: AppTypography.bodyMedium)
            .animate(delay: const Duration(milliseconds: 200))
            .fade(duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.lg),
        // Game cards grid - first row
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // High vs Low game
              Expanded(
                    child: GameCard(
                      title: 'High vs Low',
                      subtitle: 'Which note is higher?',
                      icon: Icons.swap_vert_rounded,
                      accentColor: AppColors.primary,
                      onTap: () => context.go(AppRoutes.highLow),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 300))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
              const SizedBox(width: AppSpacing.md),
              // Scale Direction game
              Expanded(
                    child: GameCard(
                      title: 'Scale Direction',
                      subtitle: 'Up or down?',
                      icon: Icons.stairs_rounded,
                      accentColor: AppColors.secondary,
                      onTap: () => context.go(AppRoutes.scaleDirection),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 400))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Game cards grid - second row
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Match the Note game
              Expanded(
                    child: GameCard(
                      title: 'Match the Note',
                      subtitle: 'Find the matching sound',
                      icon: Icons.music_note_rounded,
                      accentColor: AppColors.gold,
                      onTap: () => context.go(AppRoutes.matchNote),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 500))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
              const SizedBox(width: AppSpacing.md),
              // Interval Identification game
              Expanded(
                    child: GameCard(
                      title: 'Intervals',
                      subtitle: 'Name the interval',
                      icon: Icons.straighten_rounded,
                      accentColor: AppColors.higherButton,
                      onTap: () => context.go(AppRoutes.intervalId),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 600))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Game cards grid - third row
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chord Identification game
              Expanded(
                    child: GameCard(
                      title: 'Chords',
                      subtitle: 'Major or minor?',
                      icon: Icons.piano_rounded,
                      accentColor: AppColors.lowerButton,
                      onTap: () => context.go(AppRoutes.chordId),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 700))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
              const SizedBox(width: AppSpacing.md),
              // Same or Different game
              Expanded(
                    child: GameCard(
                      title: 'Same or Different',
                      subtitle: 'Listen & compare',
                      icon: Icons.compare_rounded,
                      accentColor: AppColors.correct,
                      onTap: () => context.go(AppRoutes.sameDifferent),
                    ),
                  )
                  .animate(delay: const Duration(milliseconds: 800))
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return SquishyButton(
          onTap: () => context.go(AppRoutes.highLow),
          backgroundColor: AppColors.primary,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                size: 32,
                color: AppColors.textOnPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Play', style: AppTypography.buttonLarge),
            ],
          ),
        )
        .animate(delay: const Duration(milliseconds: 500))
        .fade(duration: AppAnimations.medium)
        .slideY(begin: 0.2, end: 0, duration: AppAnimations.medium);
  }
}

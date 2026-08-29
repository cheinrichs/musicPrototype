import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/progress_state.dart';
import '../components/game_card.dart';
import '../theme/theme.dart';

/// Home screen with game selection and progress display
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Warm parchment backdrop, matching the radial gradients in
        // kit.css `body { background-image: ... }`
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ivory, AppColors.paper],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _buildGameSelection(context)),
              ],
            ),
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
            // Mascot + app title
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/characters/Piper_1.png',
                    width: 44,
                    height: 44,
                  ).animate().fade(duration: AppAnimations.medium).scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: AppAnimations.medium,
                    curve: AppAnimations.bounceCurve,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child:
                        Text(
                              'Ear Training Games',
                              style: AppTypography.heading2.copyWith(
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                            .animate()
                            .fade(duration: AppAnimations.medium)
                            .slideX(
                              begin: -0.1,
                              end: 0,
                              duration: AppAnimations.medium,
                            ),
                  ),
                ],
              ),
            ),
            // Right side: streak badge + skill profile icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => context.go(AppRoutes.skillProfile),
                  icon: const Icon(Icons.insights_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'Skill Profile',
                ),
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
            ),
          ],
        );
      },
    );
  }

  static const _games = [
    (
      title: 'High vs Low',
      subtitle: 'Which note is higher?',
      icon: Icons.swap_vert_rounded,
      color: AppColors.primary,
      route: AppRoutes.highLow,
    ),
    (
      title: 'Scale Direction',
      subtitle: 'Up or down?',
      icon: Icons.stairs_rounded,
      color: AppColors.secondary,
      route: AppRoutes.scaleDirection,
    ),
    (
      title: 'Match the Note',
      subtitle: 'Find the matching sound',
      icon: Icons.music_note_rounded,
      color: AppColors.gold,
      route: AppRoutes.matchNote,
    ),
    (
      title: 'Intervals',
      subtitle: 'Name the interval',
      icon: Icons.straighten_rounded,
      color: AppColors.higherButton,
      route: AppRoutes.intervalId,
    ),
    (
      title: 'Chords',
      subtitle: 'Major or minor?',
      icon: Icons.piano_rounded,
      color: AppColors.lowerButton,
      route: AppRoutes.chordId,
    ),
    (
      title: 'Same or Different',
      subtitle: 'Listen & compare',
      icon: Icons.compare_rounded,
      color: AppColors.correct,
      route: AppRoutes.sameDifferent,
    ),
    (
      title: 'Which Instrument?',
      subtitle: 'Name the sound',
      icon: Icons.spatial_audio_rounded,
      color: Color(0xFF74B9FF),
      route: AppRoutes.timbreId,
    ),
    (
      title: 'Same Beat?',
      subtitle: 'Match the rhythm',
      icon: Icons.av_timer_rounded,
      color: Color(0xFFE17055),
      route: AppRoutes.rhythmId,
    ),
    (
      title: 'Name That Note',
      subtitle: 'Do Re Mi...',
      icon: Icons.record_voice_over_rounded,
      color: AppColors.primaryLight,
      route: AppRoutes.pitchName,
    ),
  ];

  Widget _buildGameSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a game', style: AppTypography.bodyMedium)
            .animate(delay: const Duration(milliseconds: 200))
            .fade(duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemCount: _games.length,
            itemBuilder: (context, i) {
              final game = _games[i];
              return GameCard(
                    title: game.title,
                    subtitle: game.subtitle,
                    icon: game.icon,
                    accentColor: game.color,
                    onTap: () => context.go(game.route),
                  )
                  .animate(
                    delay: Duration(milliseconds: 300 + i * 75),
                  )
                  .fade(duration: AppAnimations.medium)
                  .slideY(begin: 0.1, end: 0, duration: AppAnimations.medium);
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/art_registry.dart';
import '../../app/router.dart';
import '../../app/state/profile_state.dart';
import '../../games/game_library.dart';
import '../../journey/journey_state.dart';
import '../components/circle_icon_button.dart';
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back to the SongStone landing screen — replaces the bottom nav
        // bar this screen used to share with Learning Path/Playground.
        const BackToLandingButton(),
        const SizedBox(width: AppSpacing.sm),
        // Mascot + app title
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                    'assets/images/characters/Piper_1.png',
                    width: 44,
                    height: 44,
                  )
                  .animate()
                  .fade(duration: AppAnimations.medium)
                  .scale(
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
        // Right side: skill profile icon
        IconButton(
          onPressed: () => context.go(AppRoutes.skillProfile),
          icon: const Icon(Icons.insights_rounded),
          color: AppColors.textSecondary,
          tooltip: 'Skill Profile',
        ),
      ],
    );
  }

  static const List<_Game> _games = [
    (
      id: 'high_low',
      title: 'High vs Low',
      icon: Icons.swap_vert_rounded,
      color: AppColors.primary,
      route: AppRoutes.highLow,
    ),
    (
      id: 'loud_quiet',
      title: 'Loud or Quiet',
      icon: Icons.volume_up_rounded,
      color: AppColors.gold,
      route: AppRoutes.loudQuiet,
    ),
    (
      id: 'scale_direction',
      title: 'Scale Direction',
      icon: Icons.stairs_rounded,
      color: AppColors.secondary,
      route: AppRoutes.scaleDirection,
    ),
    (
      id: 'match_note',
      title: 'Match the Note',
      icon: Icons.music_note_rounded,
      color: AppColors.gold,
      route: AppRoutes.matchNote,
    ),
    (
      id: 'interval_id',
      title: 'Intervals',
      icon: Icons.straighten_rounded,
      color: AppColors.higherButton,
      route: AppRoutes.intervalId,
    ),
    (
      id: 'chord_id',
      title: 'Chords',
      icon: Icons.piano_rounded,
      color: AppColors.lowerButton,
      route: AppRoutes.chordId,
    ),
    (
      id: 'same_different',
      title: 'Same or Different',
      icon: Icons.compare_rounded,
      color: AppColors.correct,
      route: AppRoutes.sameDifferent,
    ),
    (
      id: 'timbre_id',
      title: 'Which Instrument?',
      icon: Icons.spatial_audio_rounded,
      color: Color(0xFF74B9FF),
      route: AppRoutes.timbreId,
    ),
    (
      id: 'rhythm_id',
      title: 'Same Beat?',
      icon: Icons.av_timer_rounded,
      color: Color(0xFFE17055),
      route: AppRoutes.rhythmId,
    ),
    (
      id: 'pitch_name',
      title: 'Name That Note',
      icon: Icons.record_voice_over_rounded,
      color: AppColors.primaryLight,
      route: AppRoutes.pitchName,
    ),
  ];

  /// The games this profile's library shows. Cooper's adult profile sees
  /// every game (the dev door). A child sees [GameLibrary.defaults] plus the
  /// games they have met in the Journey; the rest are HIDDEN, not shown
  /// locked. This never touches the Journey's own game pool.
  List<_Game> _visibleGames(BuildContext context) {
    ProfileState? profiles;
    JourneyState? journey;
    try {
      profiles = context.watch<ProfileState>();
    } on ProviderNotFoundException {
      profiles = null;
    }
    try {
      journey = context.watch<JourneyState>();
    } on ProviderNotFoundException {
      journey = null;
    }
    final profile = profiles?.activeProfile;
    final gated = profile != null && !profile.isAdult;
    final met = journey?.gamesMet ?? const <String>{};
    return [
      for (final g in _games)
        if (GameLibrary.available(g.id, gated: gated, metInJourney: met)) g,
    ];
  }

  Widget _buildGameSelection(BuildContext context) {
    final games = _visibleGames(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a game', style: AppTypography.bodyMedium)
            .animate(delay: const Duration(milliseconds: 200))
            .fade(duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fixed 2 columns assumed a tall, narrow portrait screen.
              // Now that the app is locked to landscape, pick the column
              // count from available width so cards stay a sensible size
              // instead of stretching edge-to-edge. Cards are ~50% smaller
              // than their original 170px target (Trello card 50) so more
              // are visible at once — the grid still scrolls for the rest.
              // Big enough for the painted icons to read (Cooper's mockup:
              // about seven across).
              const targetCardWidth = 120.0;
              final crossAxisCount =
                  (constraints.maxWidth / (targetCardWidth + AppSpacing.sm))
                      .floor()
                      .clamp(3, 9);

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.85,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final game = games[i];
                  return GameCard(
                        key: ValueKey('game-${game.id}'),
                        title: game.title,
                        icon: game.icon,
                        artId: Art.has('game.${game.id}')
                            ? 'game.${game.id}'
                            : null,
                        accentColor: game.color,
                        onTap: () => context.go(game.route),
                      )
                      .animate(delay: Duration(milliseconds: 300 + i * 75))
                      .fade(duration: AppAnimations.medium)
                      .slideY(
                        begin: 0.1,
                        end: 0,
                        duration: AppAnimations.medium,
                      );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

typedef _Game = ({
  String id,
  String title,
  IconData icon,
  Color color,
  String route,
});

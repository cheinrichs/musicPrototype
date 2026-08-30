import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/musical_skill.dart';
import '../../../models/game_status.dart';
import '../../../models/pitch_direction.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/glow_wiggle_character.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../models/high_low_instrument.dart';
import '../state/high_low_game_state.dart';

/// Main game screen for High/Low ear training.
///
/// Redesigned per the Trello concept art: two characters sit on stumps in
/// an illustrated forest clearing (SongStone-UI-Kit/Assets/Backgrounds/
/// Forest.png). Piper (the fox) and Clef (the animated treble clef —
/// replacement for the deprecated "blob" character) flank the scene. The
/// left character always plays the first note, the right character the
/// second; the child taps whichever one they think played the higher note
/// instead of choosing from Higher/Lower buttons. Which instrument pair
/// shows (guitar, piano, violin, ...) is randomized each round — see
/// [HighLowInstrument].
class HighLowScreen extends StatefulWidget {
  const HighLowScreen({super.key});

  @override
  State<HighLowScreen> createState() => _HighLowScreenState();
}

class _HighLowScreenState extends State<HighLowScreen> {
  late HighLowGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = HighLowGameState();
    _gameState.addListener(_onGameStateChanged);

    // Start the game automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameState.startGame();
    });
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (_gameState.status == GameStatus.completed) {
      // Record progress
      final progressState = context.read<ProgressState>();
      progressState.completeSession(
        gameType: 'high_low',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      if (_gameState.correctCount >= 4) {
        context.read<SkillState>().awardXp(
          MusicalSkill.pitchAwareness,
          _gameState.correctCount * 10,
        );
      }

      // Navigate to reward screen, forwarding path context if present.
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _gameState.correctCount,
          'totalCount': _gameState.totalPrompts,
          'gameType': 'high_low',
          'fromPath': routeExtra?['fromPath'] ?? false,
          'nodeId': routeExtra?['nodeId'],
        },
      );
    }
    setState(() {});
  }

  /// Tapping a character submits an answer. Left = "the first note was
  /// higher" (PitchDirection.lower, since correctness is defined relative
  /// to whether the *second* note was higher). Right = "the second note
  /// was higher" (PitchDirection.higher).
  void _onCharacterTap(int side) {
    if (_gameState.status != GameStatus.awaitingInput) return;
    _gameState.submitAnswer(
      side == 0 ? PitchDirection.lower : PitchDirection.higher,
    );
  }

  /// Estimated fixed heights of [_buildHeader] and [_buildTipStrip]. Used
  /// to budget how much vertical space is actually left for the scrollable
  /// [GameScreenLayout] body so it can be scaled to fit instead of
  /// scrolling — see [_buildBody].
  static const double _headerHeight = 56;
  static const double _footerHeight = 56;

  @override
  Widget build(BuildContext context) {
    return GameScreenLayout(
      // Illustrated forest clearing — SongStone-UI-Kit
      // Assets/Backgrounds/Forest.png (two stumps, matches the concept
      // art 1:1).
      background: Image.asset(
        'assets/images/backgrounds/Forest.png',
        fit: BoxFit.cover,
      ),
      header: _buildHeader(),
      body: _buildBody(context),
      footer: _buildTipStrip(),
    );
  }

  /// The app is landscape-only, so the available height for everything
  /// between the header and the footer is tight and varies a lot by
  /// device. [GameScreenLayout] falls back to scrolling if the body
  /// overflows that space, but a kid mid-round shouldn't have to scroll to
  /// see the rest of the scene — so instead we measure the real budget and
  /// scale the whole scene down to fit it, uniformly, rather than letting
  /// any one piece get clipped or overlap its neighbors.
  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final budget =
            media.size.height -
            media.padding.vertical -
            AppSpacing.sm * 2 -
            _headerHeight -
            _footerHeight -
            AppSpacing.sm;

        return SizedBox(
          width: constraints.maxWidth,
          height: budget.clamp(160.0, 900.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuestionText(),
                const SizedBox(height: AppSpacing.sm),
                _buildListenAgainButton(),
                const SizedBox(height: AppSpacing.sm),
                _buildScene(),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusText(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        _HeaderIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: () {
            final extra =
                GoRouterState.of(context).extra as Map<String, dynamic>?;
            if (extra?['fromPath'] == true) {
              context.read<ProgressState>().requestPathReturn();
            }
            context.go(AppRoutes.home);
          },
        ),
        // Progress stepper
        ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          results: _gameState.results.map((r) => r.isCorrect).toList(),
        ),
        // Skip button
        _HeaderIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Skip',
          onTap: _gameState.status == GameStatus.awaitingInput
              ? _gameState.skipPrompt
              : null,
        ),
      ],
    );
  }

  Widget _buildQuestionText() {
    final name = _gameState.currentInstrument.displayName;
    return Column(
      children: [
        Text(
              'Which $name played\na higher note?',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            )
            .animate(key: ValueKey('question-$name'))
            .fade(duration: AppAnimations.medium)
            .slideY(begin: -0.1, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Listen carefully and touch the $name\nthat played the higher note.',
          style: AppTypography.label,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListenAgainButton() {
    final canReplay = _gameState.status == GameStatus.awaitingInput;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canReplay ? _gameState.replayPrompt : null,
          child: AnimatedOpacity(
            opacity: canReplay ? 1 : 0.5,
            duration: AppAnimations.fast,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text('Listen Again', style: AppTypography.label),
      ],
    );
  }

  Widget _buildScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final charSize = (width * 0.22).clamp(60.0, 110.0);
        final instrument = _gameState.currentInstrument;

        return SizedBox(
          height: charSize + 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Piper (fox) — left flank, bottom-anchored so it, Clef, and
              // the instrument pair all share one ground line (matching
              // where the stumps sit in the background art).
              Positioned(
                left: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/characters/Piper_1.png',
                  width: charSize * 0.6,
                ).animate().fade(duration: AppAnimations.medium),
              ),
              // Clef — right flank (replacement for the deprecated blob)
              Positioned(
                right: 0,
                bottom: 0,
                child:
                    Image.asset(
                          'assets/images/characters/Clef.png',
                          width: charSize * 0.55,
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: 0,
                          end: -6,
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeInOut,
                        ),
              ),
              // Instrument pair, bottom-anchored onto the stumps
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _InstrumentButton(
                      key: ValueKey('left-${instrument.name}'),
                      assetPath: instrument.leftAssetPath,
                      size: charSize,
                      glowing: _gameState.playingIndex == 0,
                      feedback: _feedbackFor(0),
                      enabled: _gameState.status == GameStatus.awaitingInput,
                      onTap: () => _onCharacterTap(0),
                    ),
                    SizedBox(width: charSize * 0.5),
                    _InstrumentButton(
                      key: ValueKey('right-${instrument.name}'),
                      assetPath: instrument.rightAssetPath,
                      size: charSize,
                      glowing: _gameState.playingIndex == 1,
                      feedback: _feedbackFor(1),
                      enabled: _gameState.status == GameStatus.awaitingInput,
                      onTap: () => _onCharacterTap(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Correct/incorrect glow for a character side while feedback is showing.
  _CharacterFeedback? _feedbackFor(int side) {
    if (_gameState.status != GameStatus.showingFeedback) return null;
    final result = _gameState.lastResult;
    if (result == null) return null;

    // side 0 (left) is correct when the answer was "lower" (first note
    // higher); side 1 (right) is correct when the answer was "higher".
    final correctSide = result.prompt.correctAnswer == PitchDirection.higher
        ? 1
        : 0;
    if (side == correctSide) return _CharacterFeedback.correct;
    if (side == (result.userAnswer == PitchDirection.higher ? 1 : 0)) {
      return _CharacterFeedback.incorrect;
    }
    return null;
  }

  Widget _buildStatusText() {
    final name = _gameState.currentInstrument.displayName;
    String text;
    switch (_gameState.status) {
      case GameStatus.notStarted:
        text = 'Get ready...';
      case GameStatus.playing:
        text = 'Listen carefully...';
      case GameStatus.awaitingInput:
        text = 'Touch a $name!';
      case GameStatus.showingFeedback:
        final isCorrect = _gameState.lastResult?.isCorrect ?? false;
        text = isCorrect ? 'Great job!' : 'Try the next one!';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyMedium)
        .animate(key: ValueKey(_gameState.status))
        .fade(duration: AppAnimations.fast);
  }

  Widget _buildTipStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        border: Border.all(color: AppColors.cardEdge, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            size: 18,
            color: AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Higher notes sound higher up. Lower notes sound lower down.',
              style: AppTypography.label,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CharacterFeedback { correct, incorrect }

/// Small circular icon button used for the header's close/skip controls,
/// styled to match the parchment-card look used elsewhere in the Lumi
/// design system rather than a flat Material IconButton.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.4 : 1,
          duration: AppAnimations.fast,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// An instrument character sitting on a stump — glows and wiggles (via the
/// shared [GlowWiggleCharacter] treatment, same as the Sound Playground)
/// while its note plays, and tappable once the round is awaiting an
/// answer.
class _InstrumentButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final _CharacterFeedback? feedback;
  final bool enabled;
  final VoidCallback onTap;

  const _InstrumentButton({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowing,
    required this.feedback,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color glowColor;
    if (feedback == _CharacterFeedback.correct) {
      glowColor = AppColors.correct;
    } else if (feedback == _CharacterFeedback.incorrect) {
      glowColor = AppColors.incorrect;
    } else {
      glowColor = AppColors.gold;
    }
    final showGlow = glowing || feedback != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: GlowWiggleCharacter(
        size: size,
        isActive: showGlow,
        glowColor: glowColor,
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}

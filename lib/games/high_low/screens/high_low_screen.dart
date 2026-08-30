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
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../state/high_low_game_state.dart';

/// Main game screen for High/Low ear training.
///
/// Redesigned per the Trello concept art: two guitars sit on stumps in an
/// illustrated forest clearing (SongStone-UI-Kit/Assets/Backgrounds/
/// Forest.png). Piper (the fox) and Clef (the animated treble clef —
/// replacement for the deprecated "blob" character) flank the scene. The
/// left guitar always plays the first note, the right guitar the second;
/// the child taps whichever guitar they think played the higher note
/// instead of choosing from Higher/Lower buttons.
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

  /// Tapping a guitar submits an answer. Left guitar = "the first note was
  /// higher" (PitchDirection.lower, since correctness is defined relative
  /// to whether the *second* note was higher). Right guitar = "the second
  /// note was higher" (PitchDirection.higher).
  void _onGuitarTap(int side) {
    if (_gameState.status != GameStatus.awaitingInput) return;
    _gameState.submitAnswer(
      side == 0 ? PitchDirection.lower : PitchDirection.higher,
    );
  }

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
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuestionText(),
          const SizedBox(height: AppSpacing.md),
          _buildListenAgainButton(),
          const SizedBox(height: AppSpacing.lg),
          _buildScene(),
          const SizedBox(height: AppSpacing.md),
          _buildStatusText(),
        ],
      ),
      footer: _buildTipStrip(),
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
    return Column(
      children: [
        Text(
              'Which guitar played\na higher note?',
              style: AppTypography.heading2,
              textAlign: TextAlign.center,
            )
            .animate()
            .fade(duration: AppAnimations.medium)
            .slideY(begin: -0.1, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Listen carefully and touch the guitar\nthat played the higher note.',
          style: AppTypography.bodyMedium,
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
              width: 64,
              height: 64,
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
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Listen Again', style: AppTypography.label),
      ],
    );
  }

  Widget _buildScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final guitarSize = (width * 0.32).clamp(90.0, 160.0);

        return SizedBox(
          height: guitarSize + 90,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Piper (fox) — left flank
              Positioned(
                left: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/characters/Piper_1.png',
                  width: guitarSize * 0.6,
                ).animate().fade(duration: AppAnimations.medium),
              ),
              // Clef — right flank (replacement for the deprecated blob)
              Positioned(
                right: 0,
                bottom: 0,
                child:
                    Image.asset(
                          'assets/images/characters/Clef.png',
                          width: guitarSize * 0.55,
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: 0,
                          end: -6,
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeInOut,
                        ),
              ),
              // Guitars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _GuitarButton(
                    assetPath: 'assets/images/characters/instruments/Guitar1.png',
                    size: guitarSize,
                    glowing: _gameState.playingIndex == 0,
                    feedback: _feedbackFor(0),
                    enabled: _gameState.status == GameStatus.awaitingInput,
                    onTap: () => _onGuitarTap(0),
                  ),
                  SizedBox(width: guitarSize * 0.5),
                  _GuitarButton(
                    assetPath: 'assets/images/characters/instruments/Guitar2.png',
                    size: guitarSize,
                    glowing: _gameState.playingIndex == 1,
                    feedback: _feedbackFor(1),
                    enabled: _gameState.status == GameStatus.awaitingInput,
                    onTap: () => _onGuitarTap(1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Correct/incorrect glow for a guitar side while feedback is showing.
  _GuitarFeedback? _feedbackFor(int side) {
    if (_gameState.status != GameStatus.showingFeedback) return null;
    final result = _gameState.lastResult;
    if (result == null) return null;

    // side 0 (left) is correct when the answer was "lower" (first note
    // higher); side 1 (right) is correct when the answer was "higher".
    final correctSide = result.prompt.correctAnswer == PitchDirection.higher
        ? 1
        : 0;
    if (side == correctSide) return _GuitarFeedback.correct;
    if (side == (result.userAnswer == PitchDirection.higher ? 1 : 0)) {
      return _GuitarFeedback.incorrect;
    }
    return null;
  }

  Widget _buildStatusText() {
    String text;
    switch (_gameState.status) {
      case GameStatus.notStarted:
        text = 'Get ready...';
      case GameStatus.playing:
        text = 'Listen carefully...';
      case GameStatus.awaitingInput:
        text = 'Touch a guitar!';
      case GameStatus.showingFeedback:
        final isCorrect = _gameState.lastResult?.isCorrect ?? false;
        text = isCorrect ? 'Great job!' : 'Try the next one!';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyLarge)
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

enum _GuitarFeedback { correct, incorrect }

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

/// A guitar image sitting on a stump, glowing while its note plays and
/// tappable once the round is awaiting an answer.
class _GuitarButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final _GuitarFeedback? feedback;
  final bool enabled;
  final VoidCallback onTap;

  const _GuitarButton({
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
    if (feedback == _GuitarFeedback.correct) {
      glowColor = AppColors.correct;
    } else if (feedback == _GuitarFeedback.incorrect) {
      glowColor = AppColors.incorrect;
    } else {
      glowColor = AppColors.gold;
    }
    final showGlow = glowing || feedback != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.55),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    ).animate(target: showGlow ? 1 : 0).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.06, 1.06),
      duration: AppAnimations.fast,
    );
  }
}

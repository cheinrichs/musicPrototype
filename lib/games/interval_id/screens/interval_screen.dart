import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/musical_skill.dart';
import '../../../models/game_status.dart';
import '../../../models/interval_type.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/components/squishy_button.dart';
import '../../../ui/theme/theme.dart';
import '../state/interval_game_state.dart';

/// Main game screen for Interval Identification ear training
class IntervalScreen extends StatefulWidget {
  const IntervalScreen({super.key});

  @override
  State<IntervalScreen> createState() => _IntervalScreenState();
}

class _IntervalScreenState extends State<IntervalScreen> {
  late IntervalGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = IntervalGameState();
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
        gameType: 'interval_id',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      context.read<SkillState>().awardXp(
        MusicalSkill.pitchAwareness,
        _gameState.correctCount * 10,
      );

      // Navigate to reward screen, forwarding path context if present.
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _gameState.correctCount,
          'totalCount': _gameState.totalPrompts,
          'gameType': 'interval_id',
          'fromPath': routeExtra?['fromPath'] ?? false,
          'nodeId': routeExtra?['nodeId'],
        },
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(),
              _buildGameContent(),
              const Spacer(),
              _buildControls(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        IconButton(
          onPressed: () {
            final extra =
                GoRouterState.of(context).extra as Map<String, dynamic>?;
            if (extra?['fromPath'] == true) {
              context.read<ProgressState>().requestPathReturn();
            }
            context.go(AppRoutes.home);
          },
          icon: const Icon(Icons.close),
          iconSize: 28,
          color: AppColors.textSecondary,
        ),
        // Progress dots
        ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          results: _gameState.results.map((r) => r.isCorrect).toList(),
        ),
        // Spacer for symmetry
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildGameContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Feedback indicator
        _buildFeedbackIndicator(),
        const SizedBox(height: AppSpacing.xl),
        // Question text
        Text(
              'What interval is this?',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            )
            .animate()
            .fade(duration: AppAnimations.medium)
            .slideY(begin: -0.1, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.md),
        // Status indicator
        _buildStatusText(),
      ],
    );
  }

  Widget _buildFeedbackIndicator() {
    if (_gameState.status != GameStatus.showingFeedback) {
      return const SizedBox(height: 80);
    }

    final lastResult = _gameState.lastResult;
    if (lastResult == null) return const SizedBox(height: 80);

    final isCorrect = lastResult.isCorrect;

    return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isCorrect
                ? AppColors.correctLight
                : AppColors.incorrectLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCorrect ? Icons.check_rounded : Icons.close_rounded,
            size: 48,
            color: isCorrect ? AppColors.correct : AppColors.incorrect,
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          duration: AppAnimations.correctFeedback,
          curve: AppAnimations.bounceCurve,
        )
        .fade(begin: 0, end: 1, duration: AppAnimations.fast);
  }

  Widget _buildStatusText() {
    String text;
    switch (_gameState.status) {
      case GameStatus.notStarted:
        text = 'Get ready...';
      case GameStatus.playing:
        text = 'Listen to the interval...';
      case GameStatus.awaitingInput:
        text = 'Tap your answer!';
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

  Widget _buildControls() {
    final canAnswer = _gameState.status == GameStatus.awaitingInput;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Answer buttons - 2x2 grid
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIntervalButton(IntervalType.minorThird, canAnswer),
            const SizedBox(width: AppSpacing.md),
            _buildIntervalButton(IntervalType.majorThird, canAnswer),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIntervalButton(IntervalType.perfectFifth, canAnswer),
            const SizedBox(width: AppSpacing.md),
            _buildIntervalButton(IntervalType.octave, canAnswer),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // Replay button
        TextButton.icon(
          onPressed: canAnswer ? () => _gameState.replayPrompt() : null,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildIntervalButton(IntervalType interval, bool enabled) {
    // Different colors for each interval
    Color color;
    switch (interval) {
      case IntervalType.minorThird:
        color = AppColors.primary;
      case IntervalType.majorThird:
        color = AppColors.secondary;
      case IntervalType.perfectFifth:
        color = AppColors.gold;
      case IntervalType.octave:
        color = AppColors.higherButton;
    }

    return SizedBox(
      width: 140,
      child: SquishyButton(
        onTap: enabled ? () => _gameState.submitAnswer(interval) : null,
        backgroundColor: enabled ? color : color.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              interval.shortLabel,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              interval.displayName,
              style: AppTypography.label.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

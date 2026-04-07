import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../models/game_status.dart';
import '../../../models/scale_direction.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/components/squishy_button.dart';
import '../../../ui/theme/theme.dart';
import '../state/scale_direction_game_state.dart';

/// Main game screen for Scale Direction ear training
class ScaleDirectionScreen extends StatefulWidget {
  const ScaleDirectionScreen({super.key});

  @override
  State<ScaleDirectionScreen> createState() => _ScaleDirectionScreenState();
}

class _ScaleDirectionScreenState extends State<ScaleDirectionScreen> {
  late ScaleDirectionGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = ScaleDirectionGameState();
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
        gameType: 'scale_direction',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );

      // Navigate to reward screen, forwarding path context if present.
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _gameState.correctCount,
          'totalCount': _gameState.totalPrompts,
          'gameType': 'scale_direction',
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
          onPressed: () => context.go(AppRoutes.home),
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
              'Is the scale going\nup or down?',
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
        text = 'Listen to the scale...';
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
        // Answer buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameChoiceButton(
              label: 'Up',
              icon: Icons.arrow_upward_rounded,
              color: AppColors.secondary,
              enabled: canAnswer,
              onTap: canAnswer
                  ? () => _gameState.submitAnswer(ScaleDirection.ascending)
                  : null,
            ),
            const SizedBox(width: AppSpacing.lg),
            GameChoiceButton(
              label: 'Down',
              icon: Icons.arrow_downward_rounded,
              color: AppColors.primary,
              enabled: canAnswer,
              onTap: canAnswer
                  ? () => _gameState.submitAnswer(ScaleDirection.descending)
                  : null,
            ),
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
}

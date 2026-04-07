import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../models/game_status.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/components/squishy_button.dart';
import '../../../ui/theme/theme.dart';
import '../state/match_note_game_state.dart';

/// Main game screen for Match the Note ear training
class MatchNoteScreen extends StatefulWidget {
  const MatchNoteScreen({super.key});

  @override
  State<MatchNoteScreen> createState() => _MatchNoteScreenState();
}

class _MatchNoteScreenState extends State<MatchNoteScreen> {
  late MatchNoteGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = MatchNoteGameState();
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
        gameType: 'match_note',
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
          'gameType': 'match_note',
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
              'Match the note!',
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
        text = 'Listen to the target note...';
      case GameStatus.awaitingInput:
        text = _gameState.hasSelection
            ? 'Tap Submit when ready!'
            : 'Tap a button to hear it';
      case GameStatus.showingFeedback:
        final isCorrect = _gameState.lastResult?.isCorrect ?? false;
        text = isCorrect ? 'Great job!' : 'Try the next one!';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyMedium)
        .animate(
          key: ValueKey('${_gameState.status}_${_gameState.hasSelection}'),
        )
        .fade(duration: AppAnimations.fast);
  }

  Widget _buildControls() {
    final canAnswer = _gameState.status == GameStatus.awaitingInput;
    final showingFeedback = _gameState.status == GameStatus.showingFeedback;
    final lastResult = _gameState.lastResult;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note choice buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              _buildNoteButton(
                index: i,
                enabled: canAnswer,
                isSelected: _gameState.selectedChoiceIndex == i,
                showCorrect:
                    showingFeedback &&
                    lastResult != null &&
                    i == lastResult.prompt.correctIndex,
                showWrong:
                    showingFeedback &&
                    lastResult != null &&
                    i == lastResult.userChoiceIndex &&
                    !lastResult.isCorrect,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Submit button
        SquishyButton(
          onTap: canAnswer && _gameState.hasSelection
              ? () => _gameState.submitAnswer()
              : null,
          backgroundColor: canAnswer && _gameState.hasSelection
              ? AppColors.primary
              : AppColors.surface,
          width: 160,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_rounded,
                color: canAnswer && _gameState.hasSelection
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Submit',
                style: AppTypography.buttonMedium.copyWith(
                  color: canAnswer && _gameState.hasSelection
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Replay button
        TextButton.icon(
          onPressed: canAnswer ? () => _gameState.replayTarget() : null,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNoteButton({
    required int index,
    required bool enabled,
    required bool isSelected,
    required bool showCorrect,
    required bool showWrong,
  }) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (showCorrect) {
      backgroundColor = AppColors.correctLight;
      borderColor = AppColors.correct;
      textColor = AppColors.correct;
    } else if (showWrong) {
      backgroundColor = AppColors.incorrectLight;
      borderColor = AppColors.incorrect;
      textColor = AppColors.incorrect;
    } else if (isSelected) {
      backgroundColor = AppColors.primary.withValues(alpha: 0.15);
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
    } else {
      backgroundColor = AppColors.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
      textColor = enabled ? AppColors.textPrimary : AppColors.textSecondary;
    }

    Widget button = GestureDetector(
      onTap: enabled ? () => _gameState.selectChoice(index) : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: isSelected || showCorrect || showWrong ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: AppTypography.heading2.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    // Add animation for correct answer feedback
    if (showCorrect) {
      button = button
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: const Duration(milliseconds: 300),
          );
    }

    return button;
  }
}

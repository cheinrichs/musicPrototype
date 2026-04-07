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
import '../state/same_different_game_state.dart';

/// Main game screen for Same or Different ear training
class SameDifferentScreen extends StatefulWidget {
  const SameDifferentScreen({super.key});

  @override
  State<SameDifferentScreen> createState() => _SameDifferentScreenState();
}

class _SameDifferentScreenState extends State<SameDifferentScreen> {
  late SameDifferentGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = SameDifferentGameState();
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
        gameType: 'same_different',
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
          'gameType': 'same_different',
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
              'Same or different?',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            )
            .animate()
            .fade(duration: AppAnimations.medium)
            .slideY(begin: -0.1, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.md),
        // Status indicator
        _buildStatusText(),
        const SizedBox(height: AppSpacing.lg),
        // Melody phase indicator
        _buildMelodyIndicator(),
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
        if (_gameState.melodyPhase == MelodyPhase.first) {
          text = 'Listen to melody 1...';
        } else {
          text = 'Listen to melody 2...';
        }
      case GameStatus.awaitingInput:
        text = 'Were they the same?';
      case GameStatus.showingFeedback:
        final isCorrect = _gameState.lastResult?.isCorrect ?? false;
        text = isCorrect ? 'Great ears!' : 'Try the next one!';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyMedium)
        .animate(
          key: ValueKey('${_gameState.status}_${_gameState.melodyPhase}'),
        )
        .fade(duration: AppAnimations.fast);
  }

  Widget _buildMelodyIndicator() {
    final isPlaying = _gameState.status == GameStatus.playing;
    final phase = _gameState.melodyPhase;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Melody 1 indicator
        _buildMelodyDot(
          label: '1',
          isActive: isPlaying && phase == MelodyPhase.first,
          isComplete: phase != MelodyPhase.first || !isPlaying,
        ),
        const SizedBox(width: AppSpacing.lg),
        // Arrow
        Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.textSecondary,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.lg),
        // Melody 2 indicator
        _buildMelodyDot(
          label: '2',
          isActive: isPlaying && phase == MelodyPhase.second,
          isComplete: phase == MelodyPhase.done,
        ),
      ],
    );
  }

  Widget _buildMelodyDot({
    required String label,
    required bool isActive,
    required bool isComplete,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : isComplete
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Center(
        child: isActive
            ? Icon(
                    Icons.music_note_rounded,
                    color: AppColors.textOnPrimary,
                    size: 24,
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    duration: const Duration(milliseconds: 400),
                  )
                  .then()
                  .scale(
                    begin: const Offset(1.2, 1.2),
                    end: const Offset(0.8, 0.8),
                    duration: const Duration(milliseconds: 400),
                  )
            : Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: isComplete
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
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
            _buildAnswerButton(
              label: 'Same',
              icon: Icons.drag_handle_rounded,
              color: AppColors.correct,
              isSame: true,
              enabled: canAnswer,
            ),
            const SizedBox(width: AppSpacing.lg),
            _buildAnswerButton(
              label: 'Different',
              icon: Icons.compare_arrows_rounded,
              color: AppColors.secondary,
              isSame: false,
              enabled: canAnswer,
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

  Widget _buildAnswerButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSame,
    required bool enabled,
  }) {
    return SizedBox(
      width: 140,
      child: SquishyButton(
        onTap: enabled ? () => _gameState.submitAnswer(isSame) : null,
        backgroundColor: enabled ? color : color.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textOnPrimary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.buttonMedium.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

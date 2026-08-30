import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/game_status.dart';
import '../../../models/musical_skill.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/components/squishy_button.dart';
import '../../../ui/theme/theme.dart';
import '../state/rhythm_game_state.dart';

class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key});

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen> {
  late RhythmGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = RhythmGameState();
    _gameState.addListener(_onGameStateChanged);
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
      context.read<ProgressState>().completeSession(
        gameType: 'rhythm_id',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      if (_gameState.correctCount >= 4) {
        context.read<SkillState>().awardXp(
          MusicalSkill.rhythmAndTiming,
          _gameState.correctCount * 10,
        );
      }
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(AppRoutes.reward, extra: {
        'correctCount': _gameState.correctCount,
        'totalCount': _gameState.totalPrompts,
        'gameType': 'rhythm_id',
        'fromPath': routeExtra?['fromPath'] ?? false,
        'nodeId': routeExtra?['nodeId'],
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GameScreenLayout(
      header: _buildHeader(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGameContent(),
          const SizedBox(height: AppSpacing.xl),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
        ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          results: _gameState.results.map((r) => r.isCorrect).toList(),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildGameContent() {
    final isPlaying = _gameState.status == GameStatus.playing;
    final lastResult = _gameState.lastResult;
    final showFeedback =
        _gameState.status == GameStatus.showingFeedback && lastResult != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFeedback)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: lastResult.isCorrect
                  ? AppColors.correctLight
                  : AppColors.incorrectLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              lastResult.isCorrect
                  ? Icons.check_rounded
                  : Icons.close_rounded,
              size: 48,
              color: lastResult.isCorrect
                  ? AppColors.correct
                  : AppColors.incorrect,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: AppAnimations.correctFeedback,
                curve: AppAnimations.bounceCurve,
              )
              .fade(begin: 0, end: 1, duration: AppAnimations.fast)
        else
          AnimatedScale(
            scale: isPlaying ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: const SizedBox(
              width: 80,
              height: 80,
              child: Center(
                child: Text('🥁', style: TextStyle(fontSize: 56)),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _promptLabel(),
          style: AppTypography.heading3,
          textAlign: TextAlign.center,
        )
            .animate(
              key: ValueKey('${_gameState.status}_${_gameState.phase}'),
            )
            .fade(duration: AppAnimations.fast),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _statusText(),
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        )
            .animate(key: ValueKey(_gameState.status))
            .fade(duration: AppAnimations.fast),
      ],
    );
  }

  String _promptLabel() {
    switch (_gameState.status) {
      case GameStatus.playing:
        return _gameState.phase == RhythmPhase.patternA
            ? 'Pattern 1'
            : 'Pattern 2';
      case GameStatus.awaitingInput:
        return 'Same or different?';
      case GameStatus.showingFeedback:
        final result = _gameState.lastResult;
        if (result == null) return '';
        return result.isCorrect ? 'Nice!' : 'Not quite!';
      default:
        return 'Get ready...';
    }
  }

  String _statusText() {
    switch (_gameState.status) {
      case GameStatus.playing:
        return 'Listen carefully...';
      case GameStatus.awaitingInput:
        return 'Did the two patterns sound the same?';
      case GameStatus.showingFeedback:
        final result = _gameState.lastResult;
        if (result == null) return '';
        return result.areSame
            ? 'They were the same!'
            : 'They were different!';
      default:
        return '';
    }
  }

  Widget _buildControls() {
    final canAnswer = _gameState.status == GameStatus.awaitingInput;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameChoiceButton(
              label: 'Same!',
              icon: Icons.compare_arrows_rounded,
              color: AppColors.higherButton,
              enabled: canAnswer,
              onTap: canAnswer ? () => _gameState.submitAnswer(true) : null,
            ),
            const SizedBox(width: AppSpacing.lg),
            GameChoiceButton(
              label: 'Different!',
              icon: Icons.shuffle_rounded,
              color: AppColors.lowerButton,
              enabled: canAnswer,
              onTap: canAnswer ? () => _gameState.submitAnswer(false) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton.icon(
          onPressed: canAnswer ? _gameState.replay : null,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }
}

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
import '../state/pitch_name_game_state.dart';

const List<Color> _choiceColors = [
  Color(0xFF6C5CE7),
  Color(0xFF00B894),
  Color(0xFFE17055),
  Color(0xFF74B9FF),
];

class PitchNameScreen extends StatefulWidget {
  const PitchNameScreen({super.key});

  @override
  State<PitchNameScreen> createState() => _PitchNameScreenState();
}

class _PitchNameScreenState extends State<PitchNameScreen> {
  late PitchNameGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = PitchNameGameState();
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
        gameType: 'pitch_name',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      if (_gameState.correctCount >= 4) {
        context.read<SkillState>().awardXp(
          MusicalSkill.pitchNaming,
          _gameState.correctCount * 10,
        );
      }
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(AppRoutes.reward, extra: {
        'correctCount': _gameState.correctCount,
        'totalCount': _gameState.totalPrompts,
        'gameType': 'pitch_name',
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
          _buildChoices(),
          const SizedBox(height: AppSpacing.xl),
          _buildReplayButton(),
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
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: const Text('🎵', style: TextStyle(fontSize: 64)),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _statusText(),
          style: AppTypography.heading3,
          textAlign: TextAlign.center,
        )
            .animate(key: ValueKey(_gameState.status))
            .fade(duration: AppAnimations.fast),
      ],
    );
  }

  String _statusText() {
    switch (_gameState.status) {
      case GameStatus.playing:
        return 'Listen...';
      case GameStatus.awaitingInput:
        return 'What note is that?';
      case GameStatus.showingFeedback:
        final result = _gameState.lastResult;
        if (result == null) return '';
        return result.isCorrect
            ? 'That\'s it!'
            : 'It was ${result.correct.solfege}!';
      default:
        return '';
    }
  }

  Widget _buildChoices() {
    final canAnswer = _gameState.status == GameStatus.awaitingInput;
    final showFeedback = _gameState.status == GameStatus.showingFeedback;
    final lastResult = _gameState.lastResult;
    final choices = _gameState.choices;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.center,
      children: List.generate(choices.length, (i) {
        final choice = choices[i];
        final baseColor = _choiceColors[i % _choiceColors.length];
        Color buttonColor = baseColor;

        if (showFeedback && lastResult != null) {
          if (choice.solfege == lastResult.correct.solfege) {
            buttonColor = AppColors.correct;
          } else if (choice.solfege == lastResult.selected.solfege &&
              !lastResult.isCorrect) {
            buttonColor = AppColors.incorrect;
          }
        }

        return SquishyButton(
          onTap: canAnswer ? () => _gameState.submitAnswer(choice) : null,
          backgroundColor: buttonColor,
          enabled: canAnswer,
          width: 130,
          height: 72,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            choice.solfege,
            style: AppTypography.heading3
                .copyWith(color: AppColors.textOnPrimary),
          ),
        );
      }),
    );
  }

  Widget _buildReplayButton() {
    final canReplay = _gameState.status == GameStatus.awaitingInput;
    return TextButton.icon(
      onPressed: canReplay ? _gameState.replay : null,
      icon: const Icon(Icons.replay_rounded),
      label: const Text('Hear it again'),
      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
    );
  }
}

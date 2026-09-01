import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../audio/audio_controller.dart';
import '../../../models/game_status.dart';
import '../../../models/instrument.dart';
import '../../../models/musical_skill.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../state/timbre_game_state.dart';

class TimbreScreen extends StatefulWidget {
  const TimbreScreen({super.key});

  @override
  State<TimbreScreen> createState() => _TimbreScreenState();
}

class _TimbreScreenState extends State<TimbreScreen> {
  late TimbreGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = TimbreGameState();
    _gameState.addListener(_onGameStateChanged);
    AudioController.instance.preloadClips(
      timbrePool.expand((i) => i.assetPaths).toList(),
    );
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
        gameType: 'timbre_id',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      if (_gameState.correctCount >= 4) {
        context.read<SkillState>().awardXp(
          MusicalSkill.timbreAndInstrument,
          _gameState.correctCount * 10,
        );
      }
      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _gameState.correctCount,
          'totalCount': _gameState.totalPrompts,
          'gameType': 'timbre_id',
          'fromPath': routeExtra?['fromPath'] ?? false,
          'nodeId': routeExtra?['nodeId'],
        },
      );
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
          _buildPromptArea(),
          const SizedBox(height: AppSpacing.xl),
          _buildInstrumentGrid(),
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
          completedCount: _gameState.results.length,
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildPromptArea() {
    final isPlaying = _gameState.status == GameStatus.playing;
    final lastResult = _gameState.lastResult;
    final showFeedback =
        _gameState.status == GameStatus.showingFeedback && lastResult != null;

    return Column(
      children: [
        if (showFeedback)
          Container(
                width: 72,
                height: 72,
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
                  size: 40,
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
            scale: isPlaying ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: const Text('🎧', style: TextStyle(fontSize: 64)),
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
        return 'Which instrument is that?';
      case GameStatus.showingFeedback:
        final result = _gameState.lastResult;
        if (result == null) return '';
        return result.isCorrect
            ? 'Nice one!'
            : 'That was ${result.correct.label}!';
      default:
        return '';
    }
  }

  Widget _buildInstrumentGrid() {
    final canAnswer = _gameState.status == GameStatus.awaitingInput;
    final showFeedback = _gameState.status == GameStatus.showingFeedback;
    final lastResult = _gameState.lastResult;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.center,
      children: timbrePool.map((instrument) {
        Color? overlayColor;
        Widget? badge;

        if (showFeedback && lastResult != null) {
          if (instrument == lastResult.correct) {
            overlayColor = AppColors.correct.withValues(alpha: 0.2);
            badge = const Icon(
              Icons.check_rounded,
              color: AppColors.correct,
              size: 20,
            );
          } else if (instrument == lastResult.selected &&
              !lastResult.isCorrect) {
            overlayColor = AppColors.incorrect.withValues(alpha: 0.2);
            badge = const Icon(
              Icons.close_rounded,
              color: AppColors.incorrect,
              size: 20,
            );
          }
        }

        return _InstrumentButton(
          instrument: instrument,
          enabled: canAnswer,
          overlayColor: overlayColor,
          badge: badge,
          onTap: canAnswer ? () => _gameState.submitAnswer(instrument) : null,
        );
      }).toList(),
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

class _InstrumentButton extends StatefulWidget {
  final Instrument instrument;
  final bool enabled;
  final Color? overlayColor;
  final Widget? badge;
  final VoidCallback? onTap;

  const _InstrumentButton({
    required this.instrument,
    required this.enabled,
    this.overlayColor,
    this.badge,
    this.onTap,
  });

  @override
  State<_InstrumentButton> createState() => _InstrumentButtonState();
}

class _InstrumentButtonState extends State<_InstrumentButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pressController.forward().then((_) => _pressController.reverse());
    widget.onTap?.call();
  }

  // Fixed tile size — Wrap flows more tiles per row on the wide landscape
  // layout instead of a screen-width-derived size stretching each tile.
  static const double _size = 128;

  @override
  Widget build(BuildContext context) {
    const size = _size;
    final color = widget.instrument.color;

    return GestureDetector(
      onTap: widget.enabled ? _handleTap : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: size,
          height: size * 0.72,
          decoration: BoxDecoration(
            color: widget.overlayColor ?? color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.overlayColor != null
                  ? color
                  : color.withValues(alpha: 0.4),
              width: widget.overlayColor != null ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.instrument.emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instrument.label,
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (widget.badge != null)
                Positioned(top: 8, right: 8, child: widget.badge!),
            ],
          ),
        ),
      ),
    );
  }
}

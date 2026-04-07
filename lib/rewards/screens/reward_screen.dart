import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/progress_state.dart';
import '../../ui/components/squishy_button.dart';
import '../../ui/theme/theme.dart';

/// Celebration screen shown after completing a game
class RewardScreen extends StatefulWidget {
  final int correctCount;
  final int totalCount;
  final String gameType;
  final bool fromPath;
  final String? nodeId;

  const RewardScreen({
    super.key,
    required this.correctCount,
    required this.totalCount,
    required this.gameType,
    this.fromPath = false,
    this.nodeId,
  });

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: AppAnimations.confettiBurst,
    );

    // Start confetti animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  double get accuracy =>
      widget.totalCount > 0 ? widget.correctCount / widget.totalCount : 0;

  String get celebrationMessage {
    if (accuracy >= 0.9) return 'Amazing!';
    if (accuracy >= 0.7) return 'Great job!';
    if (accuracy >= 0.5) return 'Good try!';
    return 'Keep practicing!';
  }

  String get encouragementMessage {
    if (accuracy >= 0.9) return 'You have incredible ears!';
    if (accuracy >= 0.7) return 'Your listening skills are growing!';
    if (accuracy >= 0.5) return 'You\'re getting better!';
    return 'Practice makes perfect!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  const Spacer(),
                  _buildCelebration(),
                  const Spacer(),
                  _buildButtons(),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.gold,
                AppColors.correct,
                AppColors.higherButton,
                AppColors.lowerButton,
              ],
              numberOfParticles: 30,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebration() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star/trophy icon
        Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 72,
                color: AppColors.gold,
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              duration: AppAnimations.characterBounce,
              curve: AppAnimations.bounceCurve,
            )
            .then()
            .shake(
              hz: 2,
              offset: const Offset(0, 5),
              duration: const Duration(milliseconds: 500),
            ),
        const SizedBox(height: AppSpacing.xl),
        // Celebration message
        Text(
              celebrationMessage,
              style: AppTypography.heading1.copyWith(color: AppColors.primary),
            )
            .animate()
            .fade(duration: AppAnimations.medium)
            .slideY(begin: 0.2, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.md),
        // Score
        Text(
              '${widget.correctCount}/${widget.totalCount} correct',
              style: AppTypography.heading3,
            )
            .animate(delay: const Duration(milliseconds: 200))
            .fade(duration: AppAnimations.medium)
            .slideY(begin: 0.2, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.sm),
        // Encouragement
        Text(
              encouragementMessage,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            )
            .animate(delay: const Duration(milliseconds: 400))
            .fade(duration: AppAnimations.medium),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Home / Back to Path button
        SquishyButton(
              onTap: () {
                if (widget.fromPath && widget.nodeId != null) {
                  context.read<ProgressState>().completeNode(widget.nodeId!);
                  context.read<ProgressState>().requestPathReturn();
                }
                context.go(AppRoutes.home);
              },
              backgroundColor: AppColors.surface,
              shadowColor: AppColors.shadow,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.fromPath ? Icons.map_outlined : Icons.home_rounded,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.fromPath ? 'Back to Path' : 'Home',
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
            .animate(delay: const Duration(milliseconds: 600))
            .fade(duration: AppAnimations.medium)
            .slideX(begin: -0.2, end: 0, duration: AppAnimations.medium),
        const SizedBox(width: AppSpacing.md),
        // Play again button
        SquishyButton(
              onTap: () => context.go(
                _getGameRoute(),
                extra: widget.fromPath
                    ? {'fromPath': true, 'nodeId': widget.nodeId}
                    : null,
              ),
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.replay_rounded,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Play Again', style: AppTypography.buttonMedium),
                ],
              ),
            )
            .animate(delay: const Duration(milliseconds: 600))
            .fade(duration: AppAnimations.medium)
            .slideX(begin: 0.2, end: 0, duration: AppAnimations.medium),
      ],
    );
  }

  String _getGameRoute() {
    switch (widget.gameType) {
      case 'high_low':
        return AppRoutes.highLow;
      case 'scale_direction':
        return AppRoutes.scaleDirection;
      case 'match_note':
        return AppRoutes.matchNote;
      case 'interval_id':
        return AppRoutes.intervalId;
      case 'chord_id':
        return AppRoutes.chordId;
      case 'same_different':
        return AppRoutes.sameDifferent;
      default:
        return AppRoutes.highLow;
    }
  }
}

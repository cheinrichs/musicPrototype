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
          // Main content. The app is landscape-only, so the available
          // height here is tight and varies a lot by device — a
          // SingleChildScrollView let the Home button scroll off the
          // bottom of the screen entirely on short viewports (Trello card
          // yGTCNQKQ). Scaling the whole celebration block down to fit,
          // uniformly, keeps everything on one screen instead — same
          // approach as HighLowScreen's body.
          SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCelebration(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildButtons(),
                        ],
                      ),
                    ),
                  );
                },
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
        // Star badge — Lumi design system asset
        Image.asset('assets/images/ui/badge-star.png', width: 120, height: 120)
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
        // Encouragement. No visible score here (Trello card yGTCNQKQ
        // follow-up) — whether the app shows scoring at all is still an
        // open product question, and it shouldn't get answered by this
        // screen just because a number happened to be sitting right here.
        Text(
              encouragementMessage,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            )
            .animate(delay: const Duration(milliseconds: 200))
            .fade(duration: AppAnimations.medium)
            .slideY(begin: 0.2, end: 0, duration: AppAnimations.medium),
      ],
    );
  }

  Widget _buildButtons() {
    return SquishyButton(
          onTap: () {
            if (widget.fromPath && widget.nodeId != null) {
              context.read<ProgressState>().completeNode(widget.nodeId!);
              context.read<ProgressState>().requestPathReturn();
            }
            context.go(AppRoutes.home);
          },
          gradient: AppColors.ctaGradient,
          backgroundColor: AppColors.primary,
          shadowColor: AppColors.ctaShadow,
          borderRadius: AppSpacing.radiusRound,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.fromPath ? Icons.map_outlined : Icons.home_rounded,
                color: AppColors.textOnPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.fromPath ? 'Back to Path' : 'Home',
                style: AppTypography.buttonMedium,
              ),
            ],
          ),
        )
        .animate(delay: const Duration(milliseconds: 600))
        .fade(duration: AppAnimations.medium)
        .slideY(begin: 0.2, end: 0, duration: AppAnimations.medium);
  }
}

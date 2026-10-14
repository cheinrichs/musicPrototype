import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// How far through the round set the child is (Trello card 196): one
/// continuous bar — not pips — filling a step as each round ends.
///
/// **For a small child the bar is a contract, not a reward**: what it tells
/// a three-year-old is that this will end. So it only ever moves forward,
/// and when it is full the set really is over — the screen leaves (to the
/// games screen for now, a stone's celebration once stones exist; then this
/// repoints to the stone's rounds and only its denominator changes).
///
/// Sage green: outside the dial's cream-gold-orange loudness ramp, so it
/// never reads as part of Loud or Quiet's scale, and warm enough for the
/// meadow. Shared by every game.
///
/// **Short and chunky** (card 216): a third of the row it used to fill, so
/// every step is a third of the distance — a fifth of it at a five-round
/// Decide set is a small movement for a three-year-old. So it is taller than
/// it was, and each step is a visible motion: [fillDuration] long, with a
/// slight overshoot, rather than a quick slide.
class RoundSetProgressBar extends StatelessWidget {
  /// 0 to 1.
  final double progress;

  const RoundSetProgressBar({super.key, required this.progress});

  static const double height = 22;

  /// How long one step's fill takes.
  static const Duration fillDuration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress',
      value: '${(progress * 100).round()}%',
      child: Container(
        key: const ValueKey('round-set-progress'),
        height: height,
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: AppColors.cardEdge, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: fillDuration,
          curve: Curves.easeOutBack,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              key: const ValueKey('round-set-progress-fill'),
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.correct,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

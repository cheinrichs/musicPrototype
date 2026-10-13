import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Explore's correct-tap sparkle, on the instrument the child got right
/// (Trello card 189, Cooper: "the indicator needs to be on the
/// instrument"): the instrument made the sound, so the instrument answers.
/// Shared by every game that has an Explore stage.
///
/// [count] sparkles, one per correct tap so far (1-4), so each tap reads as
/// visibly *more* than the last (Cooper: "a flat sparkle is a reward; an
/// escalating one is a promise"). They stay for the rest of the round —
/// progress toward the confetti, where the music notes are a per-tap
/// response that resets — so they must not move once there: each one pops
/// in once and holds still (no idle looping motion). [size] is the
/// instrument's box.
class InstrumentSparkle extends StatelessWidget {
  final double size;
  final int count;

  const InstrumentSparkle({super.key, required this.size, required this.count});

  /// Where each sparkle sits on the instrument's box, as fractions of its
  /// size from the top and the right. Four, not five: the fifth correct tap
  /// is the confetti.
  static const List<(double top, double right)> offsets = [
    (0.02, 0.02),
    (0.22, -0.08),
    (0.02, 0.24),
    (0.42, 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(1, offsets.length);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < shown; i++)
          Positioned(
            key: ValueKey('sparkle-$i'),
            top: size * offsets[i].$1,
            right: size * offsets[i].$2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppAnimations.fast,
              curve: Curves.easeOutBack,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Text('✨', style: TextStyle(fontSize: size * 0.18)),
            ),
          ),
      ],
    );
  }
}

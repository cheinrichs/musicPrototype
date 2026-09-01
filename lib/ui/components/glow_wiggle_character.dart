import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Scale "pop" + gentle idle bob used to show that a character is currently
/// sounding.
///
/// Originally built inline for the Sound Playground's instrument
/// characters; extracted here so other screens (the High/Low game) get the
/// identical treatment instead of a second, slightly different animation.
/// Used to also draw a warm glow halo behind the character, dropped per
/// Trello card 96 — the grow + drifting notes (see [DriftingNotes], added
/// alongside this) read clearly enough on their own.
class GlowWiggleCharacter extends StatelessWidget {
  final Widget child;
  final double size;
  final bool isActive;
  final Duration bobDelay;

  /// Whether the gentle idle bob keeps running while [isActive] is false.
  /// The Sound Playground wants this (ambient life in an idle scene with
  /// several characters); High/Low wants the opposite — only the character
  /// currently sounding should move, so the "who's playing" signal reads
  /// clearly with just two characters on screen (Trello card 58).
  final bool wiggleWhenIdle;

  const GlowWiggleCharacter({
    super.key,
    required this.child,
    required this.size,
    required this.isActive,
    this.bobDelay = Duration.zero,
    this.wiggleWhenIdle = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: size, child: _buildBody());
  }

  Widget _buildBody() {
    // Always animated — never swapped for a plain `child` — so the
    // underlying AnimationController is mounted once for this button's
    // lifetime instead of being torn down and recreated every time
    // [isActive] flips. Recreating it on every flip left a zero-duration
    // startup Timer (flutter_animate's `Animate._restart`) pending whenever
    // a mount was immediately followed by a dispose in the same tick, which
    // showed up as a "Timer still pending" failure in widget tests.
    // Instead, idle just targets a flat (0) bob amplitude.
    final shouldWiggle = isActive || wiggleWhenIdle;
    return AnimatedScale(
      scale: isActive ? 1.12 : 1.0,
      duration: AppAnimations.medium,
      curve: AppAnimations.bounceCurve,
      child: child
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: shouldWiggle ? -5 : 0,
            delay: bobDelay,
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeInOut,
          ),
    );
  }
}

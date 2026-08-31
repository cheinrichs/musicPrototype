import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Warm radial glow + scale "pop" + gentle idle bob used to show that a
/// character is currently sounding.
///
/// Originally built inline for the Sound Playground's instrument
/// characters; extracted here so other screens (the High/Low game) get the
/// identical treatment instead of a second, slightly different animation.
class GlowWiggleCharacter extends StatelessWidget {
  final Widget child;
  final double size;
  final bool isActive;
  final Color glowColor;
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
    required this.glowColor,
    this.bobDelay = Duration.zero,
    this.wiggleWhenIdle = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Stack(
        alignment: Alignment.center,
        // The glow below is intentionally larger than the artwork and
        // must be allowed to spill outside this Stack's own bounds
        // without being clipped back down to size.
        clipBehavior: Clip.none,
        children: [
          // Sized *larger* than the artwork (not Positioned.fill, which
          // matched the character's own silhouette almost exactly and left
          // the radial gradient with no visible margin to bleed into — it
          // was firing but invisible, hidden behind the opaque character
          // art). The overhang doesn't affect this Stack's own reported
          // size (only non-Positioned children do), so it doesn't disturb
          // callers that position instrument buttons using [size] as their
          // footprint.
          Positioned(
            left: -size * 0.25,
            right: -size * 0.25,
            top: -size * 0.25,
            bottom: -size * 0.25,
            child: _buildGlow(),
          ),
          _buildBody(),
        ],
      ),
    );
  }

  /// Warm halo behind the character while it's sounding.
  Widget _buildGlow() {
    return AnimatedOpacity(
      opacity: isActive ? 1 : 0,
      duration: AppAnimations.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.85,
            colors: [
              glowColor.withValues(alpha: 0.75),
              glowColor.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
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
      child: child.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
        begin: 0,
        end: shouldWiggle ? -5 : 0,
        delay: bobDelay,
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeInOut,
      ),
    );
  }
}

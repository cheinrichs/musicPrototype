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

  const GlowWiggleCharacter({
    super.key,
    required this.child,
    required this.size,
    required this.isActive,
    required this.glowColor,
    this.bobDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Positioned.fill so the halo takes its size *from* the artwork
          // instead of dictating the character's footprint.
          Positioned.fill(child: _buildGlow()),
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
            radius: 0.7,
            colors: [
              glowColor.withValues(alpha: 0.55),
              glowColor.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedScale(
      scale: isActive ? 1.12 : 1.0,
      duration: AppAnimations.medium,
      curve: AppAnimations.bounceCurve,
      child: child
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: -5,
            delay: bobDelay,
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeInOut,
          ),
    );
  }
}

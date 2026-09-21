import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How one character sways while speaking.
class SwayProfile {
  /// One full there-and-back.
  final Duration period;

  /// Peak lean either side of upright, in degrees.
  final double maxDegrees;

  const SwayProfile({required this.period, required this.maxDegrees});

  /// Warm and unhurried: slower and wider.
  static const piper = SwayProfile(
    period: Duration(milliseconds: 1600),
    maxDegrees: 4.5,
  );

  /// Brighter and quicker: faster and tighter.
  static const clef = SwayProfile(
    period: Duration(milliseconds: 900),
    maxDegrees: 3.0,
  );
}

/// The "talker moves" speaking indicator (Trello card PIm7xE6n): a side-to-
/// side sway, pivoting about the character's feet, for exactly as long as
/// [speaking] is true.
///
/// A vertical bounce reads as hopping — a whole-body action, as if the
/// character were *doing* something. A sideways sway reads as weight
/// shifting, which is what a person actually does while talking. The feet
/// stay planted and the body leans either way, like a fan or pendulum.
///
/// It's an indicator, not a performance: small enough not to compete with
/// the scene, large enough to see from across a room. Piper and Clef get
/// different [SwayProfile]s so the motion carries their temperament.
///
/// Eases in and out over [_ease] and only ticks while there is something to
/// show, so a silent character is perfectly still with nothing animating.
class SpeakingSway extends StatefulWidget {
  final Widget child;
  final bool speaking;
  final bool isPiper;

  const SpeakingSway({
    super.key,
    required this.child,
    required this.speaking,
    required this.isPiper,
  });

  @override
  State<SpeakingSway> createState() => _SpeakingSwayState();
}

class _SpeakingSwayState extends State<SpeakingSway>
    with SingleTickerProviderStateMixin {
  static const Duration _ease = Duration(milliseconds: 200);

  late final AnimationController _controller;

  SwayProfile get _profile =>
      widget.isPiper ? SwayProfile.piper : SwayProfile.clef;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _profile.period);
    if (widget.speaking) _controller.repeat();
  }

  @override
  void didUpdateWidget(SpeakingSway oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _profile.period;
    if (widget.speaking && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.speaking ? 1 : 0),
      duration: _ease,
      curve: Curves.easeInOut,
      onEnd: () {
        if (!widget.speaking) _controller.stop();
      },
      child: widget.child,
      builder: (context, amplitude, child) {
        return AnimatedBuilder(
          animation: _controller,
          child: child,
          builder: (context, child) {
            final radians =
                amplitude *
                _profile.maxDegrees *
                math.pi /
                180 *
                math.sin(_controller.value * 2 * math.pi);
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.rotationZ(radians),
              child: child,
            );
          },
        );
      },
    );
  }
}

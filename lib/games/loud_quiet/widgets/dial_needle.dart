import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../ui/theme/theme.dart';
import '../models/loud_quiet_layout.dart';
import '../state/loud_quiet_game_state.dart';

/// The dial's needle (Trello card 208). Every [NeedleSwing] is one complete
/// gesture — swing out to the sound's level, wobble on arrival, home to rest
/// at the quiet end — so the same instrument tapped four times swings four
/// times. A new swing interrupts the last and starts from wherever the
/// needle is: queued, it would fall behind fast taps and show a level that
/// isn't what's playing. Turns about its measured pivot on the hub, never
/// its image centre.
class DialNeedle extends StatefulWidget {
  final NeedleSwing? swing;

  const DialNeedle({super.key, required this.swing});

  /// How long the needle takes to reach the sound's level.
  static const swingTime = Duration(milliseconds: 180);

  /// How long it wobbles on arrival.
  static const wobbleTime = Duration(milliseconds: 520);

  /// The shortest fall home, if a sound is shorter than the gesture.
  static const minReturn = Duration(milliseconds: 300);

  /// Wobble size as a share of the throw: thrown further, it wobbles more —
  /// magnitude again, for free (as an instrument landing on a stump).
  static const wobbleShare = 0.14;

  /// The needle's angle, in degrees, [elapsed] into a gesture from [start]
  /// to [target] for a sound [length] long: out fast, a damped wobble, then
  /// held high and falling home to rest as the sound decays, reaching rest
  /// as the sound ends — tracing its envelope rather than just its peak.
  static double angleAt({
    required double start,
    required double target,
    required Duration elapsed,
    required Duration length,
  }) {
    final t = elapsed.inMicroseconds / 1000.0;
    final swing = swingTime.inMicroseconds / 1000.0;
    final wobble = wobbleTime.inMicroseconds / 1000.0;
    final end = math.max(
      length.inMicroseconds / 1000.0,
      swing + wobble + minReturn.inMicroseconds / 1000.0,
    );
    const rest = LoudQuietLayout.restDegrees;
    if (t <= 0) return start;
    if (t < swing) {
      return start +
          (target - start) * Curves.easeOutCubic.transform(t / swing);
    }
    if (t < swing + wobble) {
      final w = (t - swing) / wobble;
      final amplitude = wobbleShare * (target - start);
      return target +
          amplitude * math.sin(2 * math.pi * 2.5 * w) * math.pow(1 - w, 2);
    }
    if (t < end) {
      final u = (t - swing - wobble) / (end - swing - wobble);
      return target + (rest - target) * Curves.easeInQuad.transform(u);
    }
    return rest;
  }

  /// The gesture's total time for a sound [length] long.
  static Duration totalFor(Duration length) {
    final least = swingTime + wobbleTime + minReturn;
    return length > least ? length : least;
  }

  @override
  State<DialNeedle> createState() => _DialNeedleState();
}

class _DialNeedleState extends State<DialNeedle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  double _start = LoudQuietLayout.restDegrees;
  double _target = LoudQuietLayout.restDegrees;
  Duration _length = Duration.zero;
  int? _serial;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)..addListener(_tick);
    _begin(widget.swing);
  }

  @override
  void didUpdateWidget(DialNeedle old) {
    super.didUpdateWidget(old);
    if (widget.swing?.serial != _serial) _begin(widget.swing);
  }

  Duration get _elapsed => DialNeedle.totalFor(_length) * _clock.value;

  void _begin(NeedleSwing? swing) {
    if (swing == null) return;
    // From wherever the needle is now, never from rest: interrupt, don't
    // queue.
    _start = _serial == null ? LoudQuietLayout.restDegrees : _currentAngle;
    _target = LoudQuietLayout.needleDegrees(swing.position);
    _length = swing.length;
    _serial = swing.serial;
    _clock.duration = DialNeedle.totalFor(_length);
    _clock.forward(from: 0);
  }

  double get _currentAngle => DialNeedle.angleAt(
    start: _start,
    target: _target,
    elapsed: _elapsed,
    length: _length,
  );

  void _tick() => setState(() {});

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = _serial == null ? LoudQuietLayout.restDegrees : _currentAngle;
    return Transform.rotate(
      key: const ValueKey('needle'),
      angle: angle * math.pi / 180,
      alignment: Alignment(
        LoudQuietLayout.needlePivot.dx * 2 - 1,
        LoudQuietLayout.needlePivot.dy * 2 - 1,
      ),
      child: Image.asset(
        'assets/images/backgrounds/props/DialNeedle.png',
        fit: BoxFit.fill,
      ),
    );
  }
}

/// Decide's lock over the dial's knob (Trello card 208, Cooper: "when the
/// dial doesn't move it has to look intentional"). Shut while the child is
/// being asked; a correct drop opens it — the shackle springs and it fades
/// — and the needle sweeps while the instrument plays. A wrong drop leaves
/// it shut and does nothing else: no sound, no shake. Drawn in code until
/// there is art for it.
class DialLock extends StatefulWidget {
  final bool locked;
  final double size;

  const DialLock({super.key, required this.locked, required this.size});

  @override
  State<DialLock> createState() => _DialLockState();
}

class _DialLockState extends State<DialLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.locked ? 0 : 1,
  );

  @override
  void didUpdateWidget(DialLock old) {
    super.didUpdateWidget(old);
    if (old.locked && !widget.locked) _open.forward(from: 0);
    if (!old.locked && widget.locked) _open.value = 0;
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _open,
      builder: (context, _) {
        final t = _open.value;
        if (t >= 1) return const SizedBox.shrink();
        final opened = t > 0;
        return Opacity(
          // Opens at once, then fades over the rest.
          opacity: opened ? (1 - Curves.easeIn.transform(t)) : 1,
          child: Transform.scale(
            scale: 1 + 0.15 * Curves.easeOut.transform(t),
            child: Container(
              key: const ValueKey('dial-lock'),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                opened ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: AppColors.inkBrown,
                size: widget.size * 0.6,
              ),
            ),
          ),
        );
      },
    );
  }
}

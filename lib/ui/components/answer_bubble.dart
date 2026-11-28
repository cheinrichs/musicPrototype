import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/art_registry.dart';
import 'bubble_frames.dart';

/// The commit affordance at Explore (Trello card 231): a bubble floating above
/// an instrument. Tapping the INSTRUMENT only plays it; popping its BUBBLE is
/// the answer.
///
/// - Drawn about [size] across (≈38 pt: Cooper, 2026-11-20, "Agreed on the
///   50% being the right scale"), with a [hitSize] (60 pt) square of touch
///   around it — bigger than the art, since the audience is 2 to 8. The
///   caller keeps two bubbles' hit squares apart.
/// - **Correct** ([bursting]): the 8-frame burst, played to its very last
///   frame (the tail frames ARE the dissipation), then nothing.
/// - **Wrong** (each new [wiggles]): the 5-frame wiggle, then back to rest.
///   It never bursts; the instrument never moves (that is the caller's).
/// - Every frame is drawn at the same scale as its sheet's resting bubble
///   and anchored on its OWN box centre: the wiggle's frames drift up to
///   19 px as drawn, and Cooper approved that in motion.
/// - The art is drawn in sheet regions straight from the files (manifest
///   cuts, see tool/measure_bubble_frames.py); never re-saved.
class AnswerBubble extends StatefulWidget {
  final double size;
  final double hitSize;

  /// True once this bubble's answer was right: it bursts and is gone.
  final bool bursting;

  /// Bumped by the caller for every wrong pop: each bump wiggles once.
  final int wiggles;

  /// Awake: full brightness and size, bobbing gently, poppable. ASLEEP
  /// (Cooper, 2026-11-27: the bubbles should be there "immediately upon
  /// loading"): present from the start but dimmer, smaller and still, and a
  /// tap does nothing — no wiggle (the wiggle means "wrong answer" and must
  /// not also mean "not yet"), no sound. The game wakes both together once
  /// both sounds have played, so the WAKING is the cue to choose.
  final bool awake;

  /// Called on a tap while [awake]; never while asleep.
  final VoidCallback? onPop;

  const AnswerBubble({
    super.key,
    this.size = 38,
    this.hitSize = 60,
    this.bursting = false,
    this.wiggles = 0,
    this.awake = true,
    this.onPop,
  });

  /// How long a bubble takes to wake.
  static const Duration wake = Duration(milliseconds: 450);

  /// How a sleeping bubble differs from an awake one.
  static const double asleepOpacity = 0.5;
  static const double asleepScale = 0.8;

  /// The awake bubble's gentle bob: one cycle, and how far.
  static const Duration bob = Duration(milliseconds: 1800);
  static const double bobHeight = 2.5;

  static const Duration burstFrame = Duration(milliseconds: 65);
  static const Duration wiggleFrame = Duration(milliseconds: 90);

  /// How long the burst plays, start to last frame.
  static Duration get burstDuration =>
      burstFrame * bubbleFrames['burst']!.$3.length;

  @override
  State<AnswerBubble> createState() => _AnswerBubbleState();
}

class _AnswerBubbleState extends State<AnswerBubble> {
  /// What shows now: ('idle', 0), ('wiggle', i), ('burst', i), or null.
  (String, int)? _frame = ('idle', 0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.bursting) _play('burst');
  }

  @override
  void didUpdateWidget(AnswerBubble old) {
    super.didUpdateWidget(old);
    if (widget.bursting && !old.bursting) {
      _play('burst');
    } else if (widget.wiggles != old.wiggles && !widget.bursting) {
      _play('wiggle');
    }
  }

  void _play(String sheet) {
    _timer?.cancel();
    final frames = bubbleFrames[sheet]!.$3.length;
    final step = sheet == 'burst'
        ? AnswerBubble.burstFrame
        : AnswerBubble.wiggleFrame;
    var i = 0;
    setState(() => _frame = (sheet, 0));
    _timer = Timer.periodic(step, (t) {
      if (!mounted) return t.cancel();
      i++;
      if (i < frames) {
        setState(() => _frame = (sheet, i));
      } else {
        t.cancel();
        setState(() => _frame = sheet == 'burst' ? null : ('idle', 0));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final awake = widget.awake;
    Widget art = frame == null
        ? const SizedBox.expand()
        : CustomMultiChildLayout(
            delegate: _CentreOn(),
            children: [LayoutId(id: 0, child: _frameImage(frame.$1, frame.$2))],
          );
    if (awake && frame?.$1 == 'idle') {
      art = _Bob(child: art);
    }
    return SizedBox.square(
      dimension: widget.hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Asleep, a tap is swallowed and does nothing at all.
        onTap: frame == null ? null : (awake ? widget.onPop : () {}),
        child: AnimatedOpacity(
          opacity: awake ? 1 : AnswerBubble.asleepOpacity,
          duration: AnswerBubble.wake,
          child: AnimatedScale(
            scale: awake ? 1 : AnswerBubble.asleepScale,
            duration: AnswerBubble.wake,
            curve: Curves.easeOutBack,
            child: art,
          ),
        ),
      ),
    );
  }

  /// Frame [index] of [sheet], at its sheet's resting-bubble scale.
  Widget _frameImage(String sheet, int index) {
    final (asset, image, boxes) = bubbleFrames[sheet]!;
    final box = boxes[index];
    // The sheet's resting bubble (its first frame) is drawn [size] wide.
    final scale = widget.size / boxes.first.width;
    return SizedBox(
      width: box.width * scale,
      height: box.height * scale,
      child: ImageRegion(
        art: ArtRef(asset, image: image, region: box),
      ),
    );
  }
}

/// Centres the single child in the hit square, whatever its size.
class _CentreOn extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final child = layoutChild(0, BoxConstraints.loose(Size.infinite));
    positionChild(
      0,
      Offset((size.width - child.width) / 2, (size.height - child.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_CentreOn old) => false;
}

/// The awake bubble's gentle bob. Both bubbles wake in the same frame, so
/// their bobs start together and stay in step — neither marked out.
class _Bob extends StatefulWidget {
  final Widget child;
  const _Bob({required this.child});

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AnswerBubble.bob,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.translate(
      offset: Offset(
        0,
        -AnswerBubble.bobHeight * math.sin(_c.value * 2 * math.pi),
      ),
      child: child,
    ),
    child: widget.child,
  );
}

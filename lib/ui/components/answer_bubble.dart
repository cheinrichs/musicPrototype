import 'dart:async';

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

  /// Null when the bubble cannot be popped (it is not drawn as disabled —
  /// nothing about it changes; a tap simply does nothing).
  final VoidCallback? onPop;

  const AnswerBubble({
    super.key,
    this.size = 38,
    this.hitSize = 60,
    this.bursting = false,
    this.wiggles = 0,
    this.onPop,
  });

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
    return SizedBox.square(
      dimension: widget.hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: frame == null ? null : widget.onPop,
        child: frame == null
            ? const SizedBox.expand()
            : CustomMultiChildLayout(
                delegate: _CentreOn(),
                children: [
                  LayoutId(id: 0, child: _frameImage(frame.$1, frame.$2)),
                ],
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

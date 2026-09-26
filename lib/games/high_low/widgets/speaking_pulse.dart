import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../audio/voice_envelope.dart';
import 'mouth_frames.dart';

/// The speaking indicator (Trello card PIm7xE6n) — replaces the earlier
/// bob and sway. Cooper rejected both on device with the same underlying
/// complaint: a loop is fixed motion at a fixed tempo, and speech isn't
/// periodic (it has stresses and pauses), so steady repeating motion
/// reads as a *state* the character is in — excited, fidgety — rather
/// than as talking. This drives a small scale pulse from the voice
/// line's own precomputed loudness envelope instead ([VoiceEnvelope]),
/// so the motion lands on the rhythm of the actual speech: it grows on
/// loud syllables and settles in the gaps.
///
/// Deliberately the same *kind* of cue the playing instrument's own pulse
/// already uses (`GlowWiggleCharacter`'s `isActive` scale, ~1.0-1.12) —
/// growing means "the sound is coming from me," whether it's an
/// instrument or a character speaking. But at a much smaller amplitude:
/// this scene's depth cue is that an edge (foreground) character is drawn
/// substantially larger than a centered (background) one — roughly a 40%
/// size difference (0.72 vs. 0.42 of screen height for Piper/Clef's
/// home/target heights) — and a speaking pulse anywhere near that would
/// read as the character walking toward the viewer, not talking.
/// [maxScaleDelta] stays well under both that depth gap and the
/// instrument's own pulse.
///
/// A pulse that returns to rest, never a size the character holds: it
/// eases back to 1.0 the moment [speaking] goes false, and stops ticking
/// once settled — a silent character has nothing running, the same as
/// every other idle thing on this screen.
///
/// Uses its own [Ticker], not anything derived from when a play call
/// resolves — `flutter_soloud`'s `play()` (and the note/scale playback
/// this codebase already learned the same lesson from twice) returns on
/// *start*, not completion, so it can't be used to time an animation
/// against.
class SpeakingPulse extends StatefulWidget {
  /// Peak scale increase at full envelope amplitude, e.g. 0.06 = up to
  /// 1.06x. See the class doc for why this must stay small relative to
  /// both the instrument's own ~0.12 pulse and the scene's foreground/
  /// background size ratio.
  static const double maxScaleDelta = 0.06;

  /// Static content to scale — used when only the pulse is wanted. Exactly
  /// one of [child] / [builder] is set.
  final Widget? child;

  /// Builds the content from the live eased [amplitude] (0-1) and the
  /// [MouthFrame] chosen from it, for characters that also have mouth
  /// frames. Both come from the same envelope tick as the pulse itself.
  final Widget Function(
    BuildContext context,
    double amplitude,
    MouthFrame mouth,
  )?
  builder;

  final bool speaking;

  /// The asset name (`VoiceLine.name`) of the line currently — or, while
  /// easing out, most recently — speaking. Only its envelope lookup
  /// matters; this widget doesn't otherwise know or care what `VoiceLine`
  /// is.
  final String? line;

  /// Bumped by the caller every time a new line starts speaking, even by
  /// the same character twice in a row, so this widget's elapsed-time
  /// clock resets between consecutive lines instead of running
  /// continuously across them.
  final int generation;

  const SpeakingPulse({
    super.key,
    required Widget this.child,
    required this.speaking,
    required this.line,
    required this.generation,
  }) : builder = null;

  const SpeakingPulse.builder({
    super.key,
    required MouthSpriteBuilder this.builder,
    required this.speaking,
    required this.line,
    required this.generation,
  }) : child = null;

  @override
  State<SpeakingPulse> createState() => _SpeakingPulseState();
}

class _SpeakingPulseState extends State<SpeakingPulse>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _now = Duration.zero;
  Duration _startedAt = Duration.zero;

  /// Eased amplitude actually shown, 0..1 — smooths the coarse envelope
  /// (30ms hops) into something that doesn't visibly step.
  double _displayed = 0;
  MouthFrame _mouth = MouthFrame.closed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.speaking) _ticker.start();
  }

  @override
  void didUpdateWidget(SpeakingPulse old) {
    super.didUpdateWidget(old);
    if (widget.generation != old.generation) {
      _startedAt = _now;
    }
    if (widget.speaking && !_ticker.isActive) {
      _startedAt = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _targetAmplitude {
    if (!widget.speaking) return 0;
    final line = widget.line;
    final envelope = line == null
        ? null
        : VoiceEnvelopeLibrary.envelopeForSync(line);
    if (envelope == null) {
      // No envelope yet (not recorded, or the manifest predates it) — a
      // flat mid-level amplitude so the cue still exists, just without
      // rhythm, rather than the character staying inert while it speaks.
      return 0.5;
    }
    return envelope.amplitudeAt(_now - _startedAt).clamp(0.0, 1.0);
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    // A fixed per-tick blend toward the target rather than a real
    // time-constant smoother — plenty for a coarse 30ms-hop envelope, and
    // simple. The same blend eases back to rest once [_targetAmplitude]
    // drops to 0 when [speaking] goes false, with no separate case needed.
    final target = _targetAmplitude;
    setState(() {
      _displayed += (target - _displayed) * 0.3;
      _mouth = nextMouthFrame(_mouth, _displayed);
      if (!widget.speaking && _displayed < 0.002) {
        _displayed = 0;
        _mouth = MouthFrame.closed;
      }
    });
    if (!widget.speaking && _displayed == 0) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.0 + _displayed * SpeakingPulse.maxScaleDelta,
      alignment: Alignment.bottomCenter,
      child: widget.builder != null
          ? widget.builder!(context, _displayed, _mouth)
          : widget.child,
    );
  }
}

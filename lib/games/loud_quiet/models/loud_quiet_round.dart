import 'dart:math' as math;

import '../../../models/concept_tier.dart';
import '../../high_low/models/high_low_instrument.dart';

/// One Loud or Quiet round (Trello card 162): two sounds that differ only in
/// how loud they are — the same note, and (at the one-instrument tiers) the
/// same instrument. Loudness is a playback gain on the existing samples, not
/// a recording.
class LoudQuietRound {
  final HighLowInstrument leftInstrument;
  final HighLowInstrument rightInstrument;

  /// The note both sides play. One pitch, so pitch never answers the
  /// question — a higher note sounds louder at the same level.
  final int midi;

  /// Which side is the loud one.
  final int loudSide;

  /// Gain of the quieter side, as a fraction of full (the loud side plays at
  /// full).
  final double quietGain;

  /// Which pole this round asks about: the loud one (Clef's) or the quiet
  /// one (Piper's).
  final bool asksLoud;

  const LoudQuietRound({
    required this.leftInstrument,
    required this.rightInstrument,
    required this.midi,
    required this.loudSide,
    required this.quietGain,
    required this.asksLoud,
  });

  /// The playback gain of [side].
  double gainOf(int side) => side == loudSide ? 1.0 : quietGain;

  /// The side the round asks for.
  int get targetSide => asksLoud ? loudSide : 1 - loudSide;

  HighLowInstrument instrumentOf(int side) =>
      side == 0 ? leftInstrument : rightInstrument;

  /// The gap between loud and quiet at a wide tier: 12 dB, a quarter of the
  /// amplitude. ⚠️ Card 162: the quiet end must stay audible on a bad iPad
  /// speaker in a noisy room — check on a device.
  static const double wideQuietGain = 0.25;

  /// …and at a narrow tier: 6 dB, half the amplitude.
  static const double narrowQuietGain = 0.5;

  /// The quietest gain the dial shows, at the quiet end of the needle's
  /// sweep; full gain is the loud end.
  static const double quietestGain = wideQuietGain;

  /// Where the needle points for a sound at [gain]: −1 at the quiet end of its
  /// sweep, +1 at the loud end, in decibels between them — so a narrow
  /// round's quiet sound (6 dB down) sits in the middle zone.
  static double needlePosition(double gain) {
    double db(double g) => 20 * math.log(g) / math.ln10;
    final t = (db(gain) - db(quietestGain)) / (0 - db(quietestGain));
    return (t.clamp(0.0, 1.0)) * 2 - 1;
  }

  /// A round at [tier], asking about the loud pole if [asksLoud]. Three-note
  /// tiers are not built: they play as their two-note counterparts.
  factory LoudQuietRound.generate({
    required ConceptTier tier,
    required bool asksLoud,
    required math.Random random,
  }) {
    final pool = HighLowInstrument.values;
    final left = pool[random.nextInt(pool.length)];
    var right = left;
    if (tier.instrumentsVary) {
      final others = [
        for (final i in pool)
          if (i != left && _shared(left, i).isNotEmpty) i,
      ];
      if (others.isNotEmpty) right = others[random.nextInt(others.length)];
    }
    final notes = _shared(left, right);
    final midi = notes[notes.length ~/ 2];
    return LoudQuietRound(
      leftInstrument: left,
      rightInstrument: right,
      midi: midi,
      // Either side can be the loud one, so neither position nor (at the
      // varying tiers) the instrument's own brightness answers it.
      loudSide: random.nextInt(2),
      quietGain: tier.isWide ? wideQuietGain : narrowQuietGain,
      asksLoud: asksLoud,
    );
  }

  static List<int> _shared(HighLowInstrument a, HighLowInstrument b) => [
    for (final m in a.availableMidis)
      if (b.availableMidis.contains(m)) m,
  ];
}

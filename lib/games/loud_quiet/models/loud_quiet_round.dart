import 'dart:math' as math;

import '../../high_low/models/high_low_instrument.dart';
import 'dynamic_ladder.dart';

/// One Loud or Quiet round (Trello card 162): two sounds that differ only in
/// how loud they are — the same note on the same instrument, so loudness is
/// the only difference (card 220: the ladder's one axis is dynamic
/// distance). Loudness is a playback level on the existing samples, not a
/// recording.
class LoudQuietRound {
  final HighLowInstrument leftInstrument;
  final HighLowInstrument rightInstrument;

  /// The note both sides play. One pitch, so pitch never answers the
  /// question — a higher note sounds louder at the same level.
  final int midi;

  /// Which side is the loud one.
  final int loudSide;

  /// The two sides' intended levels, in dB below full, BEFORE their
  /// instruments' trims: what the dial shows. Loud is quiet plus the step's
  /// gap (card 220 — the gap closes by bringing loud down).
  final double loudDb;
  final double quietDb;

  /// Which pole this round asks about: the loud one (Clef's) or the quiet
  /// one (Piper's).
  final bool asksLoud;

  const LoudQuietRound({
    required this.leftInstrument,
    required this.rightInstrument,
    required this.midi,
    required this.loudSide,
    required this.loudDb,
    this.quietDb = DynamicLadder.quietDb,
    required this.asksLoud,
  });

  /// The gap between the two, in dB.
  double get gapDb => loudDb - quietDb;

  /// [side]'s intended level in dB — what the needle shows.
  double levelDbOf(int side) => side == loudSide ? loudDb : quietDb;

  /// [side]'s intended level as a gain (1 at full).
  double gainOf(int side) => dbToGain(levelDbOf(side));

  /// The quiet side's intended gain.
  double get quietGain => dbToGain(quietDb);

  /// What [side] actually plays at, in dB: its instrument's
  /// [perceptualTrimDb] is its BASELINE, and the level goes on top of it
  /// (card 220: trims before the gap), so two instruments at the same
  /// intended level sound equally loud and the gap heard is the step's.
  double playbackDbOf(int side) =>
      (perceptualTrimDb[instrumentOf(side)] ?? 0) + levelDbOf(side);

  /// [playbackDbOf] as a playback gain.
  double playbackGainOf(int side) => dbToGain(playbackDbOf(side));

  /// Per-instrument trim in dB (Trello card 207), Loud or Quiet only — High
  /// vs Low shares the samples and its balance is right, so they are not
  /// re-exported. The samples sit at −18 LUFS, but LUFS is not perceived
  /// loudness: K-weighting misses sharpness, the harmonic density that makes
  /// a sound cut through. Cooper on build 90: "loud oboe sounds a little too
  /// loud, guitar and flute also just a touch too loud."
  ///
  /// ⚠️ Starting values, to be tuned by ear on a device speaker — Cooper is
  /// the measurement here, not a meter. Guitar's is smallest of the three:
  /// it is also the one whose energy a phone speaker reproduces least
  /// (≈76% above 200 Hz, tool/measure_speaker_audibility.py), so a hard cut
  /// would cost it most at the quiet end. The oboe (≈94%) can take more.
  static const Map<HighLowInstrument, double> perceptualTrimDb = {
    HighLowInstrument.oboe: -3.0,
    HighLowInstrument.flute: -1.5,
    HighLowInstrument.guitar: -1.0,
  };

  static double dbToGain(double db) => math.pow(10, db / 20).toDouble();

  /// The instruments Loud or Quiet draws from: all but the tuba. Its range
  /// here (G♯3–B3) puts only ≈60% of its energy where a phone speaker can
  /// reproduce it, so at the quiet end (−12 dB) it is the one most likely to
  /// vanish in a real room — and High vs Low already leaves it out of every
  /// tier.
  static List<HighLowInstrument> get pool => [
    for (final i in HighLowInstrument.values)
      if (i != HighLowInstrument.tuba) i,
  ];

  /// The side the round asks for.
  int get targetSide => asksLoud ? loudSide : 1 - loudSide;

  HighLowInstrument instrumentOf(int side) =>
      side == 0 ? leftInstrument : rightInstrument;

  /// Where the dial's zero sits, in dB below full: under the quietest sound
  /// it shows ([DynamicLadder.quietDb], −12 dB), so even the quietest is a short movement up from
  /// rest and the loudest is the longest (card 208 — loudness is a
  /// magnitude, not a polarity).
  static const double dialFloorDb = -14;

  /// Where the needle points for a sound at [gain]: 0 at rest (the dial's
  /// zero, below the quiet end), 1 at full, in decibels between — a wide
  /// round's quiet sound lands a seventh of the way, a narrow round's
  /// (−6 dB) a little past halfway.
  static double needlePosition(double gain) =>
      needlePositionDb(20 * math.log(gain) / math.ln10);

  /// [needlePosition] for a level in dB.
  static double needlePositionDb(double db) =>
      ((db - dialFloorDb) / -dialFloorDb).clamp(0.0, 1.0);

  /// A round at [step] of [ladder], asking about the loud pole if
  /// [asksLoud].
  factory LoudQuietRound.generate({
    required DynamicLadder ladder,
    required int step,
    required bool asksLoud,
    required math.Random random,
  }) {
    final pool = LoudQuietRound.pool;
    final instrument = pool[random.nextInt(pool.length)];
    final notes = instrument.availableMidis;
    final midi = notes[notes.length ~/ 2];
    return LoudQuietRound(
      leftInstrument: instrument,
      rightInstrument: instrument,
      midi: midi,
      // Either side can be the loud one, so position never answers it.
      loudSide: random.nextInt(2),
      loudDb: ladder.loudDbAt(step),
      asksLoud: asksLoud,
    );
  }
}

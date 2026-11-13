import 'dart:math' as math;

import '../../high_low/models/high_low_instrument.dart';
import 'dynamic_ladder.dart';

/// One Loud or Quiet round (Trello card 162): two or three sounds that
/// differ only in how loud they are — the same note on the same
/// instrument, so loudness is the only difference (card 220). Loudness is a
/// playback level on the existing samples, not a recording.
///
/// Three sounds are three DISTINCT levels, and the child picks the loudest
/// or the quietest — the shape of High vs Low's three-note rounds, never
/// odd-one-out (that is same-versus-different, another game).
class LoudQuietRound {
  /// One instrument per side, left to right.
  final List<HighLowInstrument> instruments;

  /// Each side's intended level, in dB below full, BEFORE its instrument's
  /// trim: what the dial shows. The quietest is [DynamicLadder.quietDb]; the
  /// others stand a neighbour-gap above each other (card 220 — gaps close by
  /// bringing the loud end down).
  final List<double> levelsDb;

  /// The note every side plays. One pitch, so pitch never answers the
  /// question — a higher note sounds louder at the same level.
  final int midi;

  /// Which pole this round asks about: the loudest (Clef's) or the quietest
  /// (Piper's).
  final bool asksLoud;

  const LoudQuietRound.of({
    required this.instruments,
    required this.levelsDb,
    required this.midi,
    required this.asksLoud,
  }) : assert(instruments.length == levelsDb.length);

  /// A two-sound round.
  factory LoudQuietRound({
    required HighLowInstrument leftInstrument,
    required HighLowInstrument rightInstrument,
    required int midi,
    required int loudSide,
    required double loudDb,
    double quietDb = DynamicLadder.quietDb,
    required bool asksLoud,
  }) => LoudQuietRound.of(
    instruments: [leftInstrument, rightInstrument],
    levelsDb: [
      for (var side = 0; side < 2; side++) side == loudSide ? loudDb : quietDb,
    ],
    midi: midi,
    asksLoud: asksLoud,
  );

  /// How many sounds the round compares.
  int get sideCount => instruments.length;

  HighLowInstrument get leftInstrument => instruments.first;
  HighLowInstrument get rightInstrument => instruments[1];

  /// The loudest side and the quietest.
  int get loudSide => _extreme(loudest: true);
  int get quietSide => _extreme(loudest: false);

  int _extreme({required bool loudest}) {
    var best = 0;
    for (var side = 1; side < sideCount; side++) {
      final d = levelsDb[side] - levelsDb[best];
      if (loudest ? d > 0 : d < 0) best = side;
    }
    return best;
  }

  double get loudDb => levelsDb[loudSide];
  double get quietDb => levelsDb[quietSide];

  /// The gap between NEIGHBOURING levels, in dB — the comparison the child
  /// actually makes. For two sounds, simply loud minus quiet.
  double get gapDb {
    final sorted = [...levelsDb]..sort();
    var least = double.infinity;
    for (var i = 1; i < sorted.length; i++) {
      least = math.min(least, sorted[i] - sorted[i - 1]);
    }
    return least;
  }

  /// [side]'s intended level in dB — what the needle shows.
  double levelDbOf(int side) => levelsDb[side];

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
  static List<HighLowInstrument> get pool => poolFor(2);

  /// The pool for a round of [count] instruments. Three leave out the
  /// bells too: drawn at half size, they alone would need each instrument's
  /// box twice as big to keep the touch floor, and three such boxes do not
  /// fit beside the dial — the dial would shrink to a sliver on a phone.
  /// Without them, three fit in the room two take, and the dial stays the
  /// size it is in two-instrument rounds.
  static List<HighLowInstrument> poolFor(int count) => [
    for (final i in HighLowInstrument.values)
      if (i != HighLowInstrument.tuba &&
          (count < 3 || i != HighLowInstrument.bells))
        i,
  ];

  /// The side the round asks for: the loudest, or the quietest.
  int get targetSide => asksLoud ? loudSide : quietSide;

  HighLowInstrument instrumentOf(int side) => instruments[side];

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
  /// [asksLoud]: as many sounds as the step compares, at the step's PLAYED
  /// neighbour gap (compressed where the span won't hold it — see
  /// [DynamicLadder.playedGapDbAt]), the levels shuffled across the sides
  /// so position never answers it.
  factory LoudQuietRound.generate({
    required DynamicLadder ladder,
    required int step,
    required bool asksLoud,
    required math.Random random,
  }) {
    final count = ladder.instrumentCountAt(step);
    final pool = LoudQuietRound.poolFor(count);
    final instrument = pool[random.nextInt(pool.length)];
    final notes = instrument.availableMidis;
    final midi = notes[notes.length ~/ 2];
    final gap = ladder.playedGapDbAt(step);
    final levels = [
      for (var k = 0; k < count; k++) DynamicLadder.quietDb + k * gap,
    ]..shuffle(random);
    return LoudQuietRound.of(
      instruments: List.filled(count, instrument),
      levelsDb: levels,
      midi: midi,
      asksLoud: asksLoud,
    );
  }
}

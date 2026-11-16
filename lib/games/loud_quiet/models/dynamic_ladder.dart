/// Pure Dart (no Flutter import): the curriculum generator, a plain `dart
/// run` script, reads this ladder through curriculum.dart.
library;

import '../../../models/agency_stage.dart';
import '../../high_low/models/high_low_instrument.dart';

/// How far apart the loud and quiet sounds are (Trello card 220), IN
/// DECIBELS — never a gain multiplier. Tunable by ear (the dev gate).
class DynamicDistance {
  final String id;
  final String label;

  /// The gap between the two sounds of a two-instrument round.
  final double gapDb;

  /// The target-to-nearest-competitor gap of a three-instrument round at
  /// this distance, tuned on its own (Cooper sets it by ear on a device);
  /// null plays [gapDb] — the same discrimination as the two-instrument
  /// twin, the principled default. Either way it is capped to what the span
  /// holds (see [DynamicLadder.playedGapDbAt]).
  final double? threeGapDb;

  const DynamicDistance(this.id, this.label, this.gapDb, {this.threeGapDb});

  /// The neighbour gap asked of a round of [count] instruments.
  double gapFor(int count) => count >= 3 ? (threeGapDb ?? gapDb) : gapDb;

  DynamicDistance withGap(double db) =>
      DynamicDistance(id, label, db, threeGapDb: threeGapDb);

  DynamicDistance withThreeGap(double db) =>
      DynamicDistance(id, label, gapDb, threeGapDb: db);

  @override
  bool operator ==(Object other) =>
      other is DynamicDistance &&
      other.id == id &&
      other.gapDb == gapDb &&
      other.threeGapDb == threeGapDb;

  @override
  int get hashCode => Object.hash(id, gapDb, threeGapDb);
}

/// One step of the ladder: a distance, and how many instruments are being
/// compared.
class DynamicStep {
  final String distanceId;
  final int instrumentCount;

  const DynamicStep(this.distanceId, this.instrumentCount);

  @override
  bool operator ==(Object other) =>
      other is DynamicStep &&
      other.distanceId == distanceId &&
      other.instrumentCount == instrumentCount;

  @override
  int get hashCode => Object.hash(distanceId, instrumentCount);
}

/// Loud or Quiet's own difficulty ladder (card 220): DYNAMIC DISTANCE
/// crossed with INSTRUMENT COUNT — the same shape as High vs Low's (a
/// primary listening axis crossed with how many things are compared).
/// Interval width means nothing for loudness, so it does not share High vs
/// Low's concept tiers.
///
/// ORDERED BY THE ZIGZAG RULE (Cooper's governing principle): one new demand
/// per step, and relax the others when you add one. So when the third
/// instrument arrives (T4) the distance relaxes back to EXTREME — the step
/// that introduces a third thing to compare is never also the hardest
/// listening task.
///
/// LENGTH IS DATA: [steps] and [distances] are tables, never assumed. It may
/// grow along other dimensions (instrument variety…), never through musical
/// context — a loudness change inside a phrase is its own game, Dynamics.
///
/// The three traps (card 220):
/// - The gap closes by bringing LOUD DOWN toward quiet, never by pushing
///   quiet down: quiet sits at [quietDb] on every step.
/// - Each instrument's trim goes on its BASELINE, before the gap — see
///   `LoudQuietRound.playbackDbOf`.
/// - Gaps are decibels.
class DynamicLadder {
  final List<DynamicDistance> distances;
  final List<DynamicStep> steps;

  /// How far above [floorDb] the quiet sound sits, in dB — tuned by ear on a
  /// device (the dev gate's "Quiet +" control). Loudness discrimination
  /// degrades near the hearing threshold, and at 0 the quiet sound sits ON
  /// the audibility floor, the worst place to judge it from; lifting the
  /// pair keeps every gap identical and may make a gap that is hard at the
  /// floor comfortable above it. Every dB of lift is a dB less span above.
  final double liftDb;

  /// How far above full (0 dB, the sample as normalised) each instrument's
  /// loud sound may play, in dB — its OWN ceiling. Defaults to
  /// [measuredHeadroomDb]; tunable DOWN from it in the dev gate (Cooper's
  /// ear decides how much of the clipping room is usable before a sound
  /// turns harsh), never up past it.
  final Map<HighLowInstrument, double> headroomDb;

  const DynamicLadder({
    required this.distances,
    required this.steps,
    this.liftDb = 0,
    this.headroomDb = measuredHeadroomDb,
  });

  /// The audibility floor, in dB below full (before trim): the level the
  /// game's quiet sound has always had, never lowered (card 220).
  static const double floorDb = -12;

  /// Each instrument's CLIPPING room on the note Loud or Quiet plays (the
  /// middle of its range): how far its intended level may go above full
  /// before the note's true peak, after its trim, reaches −1 dBTP. Measured
  /// 2026-11-14 by tool/measure_dynamic_headroom.py, rounded DOWN to the
  /// half-decibel. Re-measured the same day when flute and violin were
  /// extended to C7 and guitar regained A3: the played note is the middle of
  /// the range, so it MOVED (flute and violin C5 → F♯5, guitar C4 → B3).
  /// Any change to an instrument's range moves it again: re-run the tool.
  ///
  /// ⚠️ A HARD UPPER BOUND, NOT PERCEPTUAL ROOM. Peak room is not the room
  /// before a sound turns harsh on a small speaker, and no meter we have
  /// predicts that: presence-band energy, spectral centroid and crest
  /// factor were all checked against Cooper's own trims (oboe, flute,
  /// guitar sound too loud at matched LUFS) and none ranks them that way.
  /// So these are a STARTING table, every boosted instrument awaits his ear
  /// (the oboe first: it has the most room and already sounds hot), and the
  /// dev gate tunes each down.
  ///
  /// Tuba has none: Loud or Quiet never plays it.
  static const Map<HighLowInstrument, double> measuredHeadroomDb = {
    HighLowInstrument.bells: 6.5, // F♯6, true peak −7.9
    HighLowInstrument.cello: 4.5, // C5, −5.6
    HighLowInstrument.flute: 11.5, // F♯5, −11.2, trim −1.5
    HighLowInstrument.guitar: 3.0, // B3, −3.4, trim −1
    HighLowInstrument.oboe: 12.0, // C5, −10.2, trim −3
    HighLowInstrument.piano: 3.0, // C5, −4.1
    HighLowInstrument.trumpet: 10.5, // C5, −11.5
    HighLowInstrument.violin: 7.0, // F♯5, −8.1
  };

  /// [instrument]'s ceiling on this ladder, in dB above full.
  double headroomOf(HighLowInstrument instrument) =>
      headroomDb[instrument] ?? 0;

  /// The instruments Loud or Quiet may draw from for a round of [count]:
  /// all but the tuba. Its range here (G♯3–B3) puts only ≈60% of its energy
  /// where a phone speaker can reproduce it, so at the quiet end it is the
  /// one most likely to vanish in a real room — and High vs Low already
  /// leaves it out of every tier. Three leave out the bells too: drawn at
  /// half size, they alone would need each instrument's box twice as big to
  /// keep the touch floor, and three such boxes do not fit beside the dial.
  ///
  /// This is who MAY play; [eligibleAt] is who CAN play a given step.
  static List<HighLowInstrument> poolFor(int count) => [
    for (final i in HighLowInstrument.values)
      if (i != HighLowInstrument.tuba &&
          (count < 3 || i != HighLowInstrument.bells))
        i,
  ];

  /// The most room any instrument in [count]'s pool has, in dB above full.
  double maxHeadroomFor(int count) => poolFor(
    count,
  ).map(headroomOf).fold(double.negativeInfinity, (a, b) => a > b ? a : b);

  /// Whether [instrument] can play step [index] as asked: its ceiling
  /// reaches the step's loud level. The mirror of High vs Low's
  /// `HighLowInstrument.hasRangeFor` — the same shape in another
  /// dimension: an instrument that can't produce a tier's demand is
  /// EXCLUDED from that tier, never given a degraded round.
  bool hasRoomFor(HighLowInstrument instrument, int index) =>
      headroomOf(instrument) >= loudDbAt(index) - 1e-9;

  /// The instruments that can play step [index]: [poolFor] its count,
  /// filtered by [hasRoomFor]. Never empty — the played gap is at most what
  /// the roomiest instrument holds ([maxGapDbFor]).
  ///
  /// ⚠️ It shrinks as steps get EASIER: the widest gap needs the most room,
  /// so beginners get the fewest instruments. Every round plays one
  /// instrument on every side, so this count is the round's whole variety
  /// (one note each).
  List<HighLowInstrument> eligibleAt(int index) => [
    for (final i in poolFor(instrumentCountAt(index)))
      if (hasRoomFor(i, index)) i,
  ];

  /// The quiet sound's level on every step: the floor, plus [liftDb].
  double get quietDb => floorDb + liftDb;

  /// The most the quiet sound may be lifted.
  static const double maxLiftDb = 6;

  /// The narrowest a gap may be tuned to.
  static const double minGapDb = 1;

  /// The widest a gap's FIGURE may be set to. A figure wider than the span
  /// holds is compressed when played (see [playedGapDbAt]) and says so.
  static const double maxFigureDb = 24;

  /// The starting table — PLACEHOLDERS, tuned by ear on a device (the dev
  /// gate's "Gap" control). Calibrated to Cooper's ear as the CEILING, not
  /// the target: his ear is better than a three-year-old's, so anything he
  /// finds "trickier" is beyond the children, and a gap he calls tricky is
  /// the TOP of a children's ladder. On a device (2026-11-13) he found
  /// 4 dB indistinguishable, 6 "very tricky", 8 "possible but definitely
  /// trickier" — so 8 is the HARDEST rung here, not the middle one.
  ///
  /// The two-instrument and three-instrument gaps may DIVERGE: three need
  /// more span than two, so the two-instrument tiers can go wider. That is
  /// a real constraint, not a bug — never force them to match.
  static const DynamicLadder standard = DynamicLadder(
    distances: [
      DynamicDistance('extreme', 'Extreme', 16),
      DynamicDistance('moderate', 'Moderate', 12),
      DynamicDistance('subtle', 'Subtle', 8),
    ],
    steps: [
      DynamicStep('extreme', 2), // T1
      DynamicStep('moderate', 2), // T2
      DynamicStep('subtle', 2), // T3
      DynamicStep('extreme', 3), // T4 — distance relaxes as the third arrives
      DynamicStep('moderate', 3), // T5
      DynamicStep('subtle', 3), // T6
    ],
  );

  int get length => steps.length;

  /// Step [index], clamped onto the ladder.
  DynamicStep operator [](int index) => steps[clampIndex(index)];

  int clampIndex(int index) => index.clamp(0, length - 1);

  DynamicDistance distanceOf(int index) {
    final id = this[index].distanceId;
    return distances.firstWhere(
      (d) => d.id == id,
      orElse: () => throw StateError('No distance "$id" on the ladder'),
    );
  }

  /// The gap step [index] asks for, in dB: its distance's gap for its
  /// instrument count.
  double gapDbAt(int index) =>
      distanceOf(index).gapFor(instrumentCountAt(index));

  /// How far each extra instrument sits beyond the target's nearest
  /// competitor, in dB: small and FIXED. It only has to make that sound
  /// clearly not the answer; how far beyond is irrelevant to the
  /// discrimination, so it spends as little of the span as it can.
  static const double extraOffsetDb = 3;

  /// The widest gap a round of [count] instruments can play: from [quietDb]
  /// up to the ROOMIEST instrument's ceiling, less what the extra
  /// instruments take. Beyond it no instrument at all can play the step.
  double maxGapDbFor(int count) =>
      maxHeadroomFor(count) -
      quietDb -
      (count > 2 ? count - 2 : 0) * extraOffsetDb;

  /// The gap actually played at [index], in dB: between the TARGET and its
  /// NEAREST COMPETITOR. The task is "pick the loudest" (or quietest), so
  /// that one comparison is the whole difficulty — and a three-instrument
  /// tier's discrimination is exactly its two-instrument twin's. What the
  /// third instrument costs is a third thing to attend to, never a secretly
  /// smaller gap (Cooper, after build 116: even spacing needed twice the
  /// span, made T4 harder than T2 and T4 identical to T5, and broke the
  /// zigzag).
  ///
  /// The span the round needs is gap + [extraOffsetDb] per extra
  /// instrument. Instruments whose ceiling can't hold it sit the step out
  /// ([eligibleAt]); only where NO instrument can is the gap COMPRESSED, to
  /// what the roomiest holds — [isCompressedAt] says so, and the dev gate
  /// shows both figures, so the label never silently lies.
  ///
  /// NOT FOR ORDERING. A future "put them in order" task is set by its
  /// SMALLEST adjacent gap, and there equal spacing is the optimum (it
  /// maximises the smallest gap in a given span) — so ordering needs the
  /// full double span, about 6 dB per gap on this hardware. See
  /// docs/product/FUTURE_GAMES.md.
  double playedGapDbAt(int index) {
    final fits = maxGapDbFor(instrumentCountAt(index));
    return gapDbAt(index) < fits ? gapDbAt(index) : fits;
  }

  /// Whether [index]'s played gap is less than its tier's figure.
  bool isCompressedAt(int index) => playedGapDbAt(index) < gapDbAt(index);

  /// The levels a round at [index] plays, quietest first, in dB below full
  /// (before trim). Quiet is at [quietDb] whatever is asked — never below
  /// the floor. Asking for the LOUDEST: the extras sit at quiet in
  /// [extraOffsetDb] steps, and the target the played gap above the
  /// highest of them. Asking for the QUIETEST, the mirror: the target at
  /// the floor, its competitor the gap above, the extras beyond.
  List<double> levelsDbAt(int index, {required bool asksLoud}) {
    final count = instrumentCountAt(index);
    final gap = playedGapDbAt(index);
    final extras = count - 2;
    return asksLoud
        ? [
            for (var k = 0; k <= extras; k++) quietDb + k * extraOffsetDb,
            quietDb + extras * extraOffsetDb + gap,
          ]
        : [
            quietDb,
            for (var k = 0; k <= extras; k++) quietDb + gap + k * extraOffsetDb,
          ];
  }

  /// The loudest sound's level at [index], in dB below full (before trim) —
  /// the same whichever end is asked for.
  double loudDbAt(int index) =>
      quietDb +
      playedGapDbAt(index) +
      (instrumentCountAt(index) - 2) * extraOffsetDb;

  int instrumentCountAt(int index) => this[index].instrumentCount;

  /// "T1"…: the step's name, 1-based.
  String labelAt(int index) {
    final i = clampIndex(index);
    return 'T${i + 1} ${distanceOf(i).label} ×${steps[i].instrumentCount}';
  }

  /// "4": the step's number alone, for a tight chip under a "Tier" title.
  String shortLabelAt(int index) => '${clampIndex(index) + 1}';

  /// The gap each step actually plays, for reading off: "6" where it plays
  /// its figure, "12→6" where it is compressed.
  String playedGapsLabel() => _gapsLabel(
    ' · ',
    (i) => isCompressedAt(i)
        ? '${_dbText(gapDbAt(i))}→${_dbText(playedGapDbAt(i))}'
        : _dbText(gapDbAt(i)),
  );

  /// [playedGapsLabel], short and steady in length for a tight screen: the
  /// gap each step plays, starred where it is compressed below its figure.
  String playedGapsShortLabel() => _gapsLabel(
    '·',
    (i) => '${_dbText(playedGapDbAt(i))}${isCompressedAt(i) ? '*' : ''}',
  );

  String _gapsLabel(String separator, String Function(int) entry) =>
      [for (var i = 0; i < length; i++) entry(i)].join(separator);

  static String _dbText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// The lowest agency step [index] is reachable at — mirroring High vs
  /// Low's rule exactly: Observe holds at the first step, Explore stops
  /// short of three instruments, Decide reaches everything. THERE IS NO
  /// THREE-INSTRUMENT ROUND AT OBSERVE in either game (Cooper): Observe's
  /// narration is a pair ("That sounds…" / "And that sounds…"), which only
  /// works for two, and holding three sounds while each is narrated is too
  /// much to ask of a two-year-old.
  AgencyStage minAgencyAt(int index) {
    final i = clampIndex(index);
    if (i == 0) return AgencyStage.observe;
    return steps[i].instrumentCount <= 2
        ? AgencyStage.explore
        : AgencyStage.decide;
  }

  bool isReachableAt(int index, AgencyStage stage) =>
      stage.index >= minAgencyAt(index).index;

  /// [index], brought down to the highest step [stage] can reach.
  int clampedTo(int index, AgencyStage stage) {
    for (var i = clampIndex(index); i > 0; i--) {
      if (isReachableAt(i, stage)) return i;
    }
    return 0;
  }

  /// A copy with distance [distanceId]'s gap set to [db], kept within
  /// [minGapDb]–[maxFigureDb]. Every two-instrument step at that distance
  /// changes with it.
  DynamicLadder withGap(String distanceId, double db) => _copy(
    distances: [
      for (final d in distances)
        d.id == distanceId
            ? d.withGap(db.clamp(minGapDb, maxFigureDb).toDouble())
            : d,
    ],
  );

  /// A copy with distance [distanceId]'s THREE-instrument target gap set to
  /// [db], kept within [minGapDb]–[maxFigureDb].
  DynamicLadder withThreeGap(String distanceId, double db) => _copy(
    distances: [
      for (final d in distances)
        d.id == distanceId
            ? d.withThreeGap(db.clamp(minGapDb, maxFigureDb).toDouble())
            : d,
    ],
  );

  /// A copy with the quiet sound lifted [db] above the floor, kept within
  /// 0–[maxLiftDb]. Every gap stays as it is; fewer instruments have the
  /// room for it (and it is compressed where none has).
  DynamicLadder withLift(double db) =>
      _copy(liftDb: db.clamp(0, maxLiftDb).toDouble());

  /// A copy with [instrument]'s ceiling set to [db], kept within 0 and its
  /// measured clipping room — tuned down by ear, never past the point it
  /// clips.
  DynamicLadder withHeadroom(HighLowInstrument instrument, double db) => _copy(
    headroomDb: {
      ...headroomDb,
      instrument: db.clamp(0, measuredHeadroomDb[instrument] ?? 0).toDouble(),
    },
  );

  DynamicLadder _copy({
    List<DynamicDistance>? distances,
    double? liftDb,
    Map<HighLowInstrument, double>? headroomDb,
  }) => DynamicLadder(
    distances: distances ?? this.distances,
    steps: steps,
    liftDb: liftDb ?? this.liftDb,
    headroomDb: headroomDb ?? this.headroomDb,
  );

  /// The dial's loud end, in dB: the loudest TWO-instrument step's loud
  /// level, never below full. Loud may now sound above full, and the dial
  /// is a magnitude (card 208: a narrower gap swings less far), so its end
  /// has to move up with it — to the widest pair, so the extreme pair still
  /// swings right out to the loud end. A three-instrument round's loudest
  /// sits higher still (the extra instrument's offset) and lands there too.
  /// Scaled to T4's top instead, the extreme pair only just reached the
  /// loud zone.
  double get dialTopDb {
    var top = 0.0;
    for (var i = 0; i < length; i++) {
      if (instrumentCountAt(i) == 2 && loudDbAt(i) > top) top = loudDbAt(i);
    }
    return top;
  }

  /// Sets the gap step [index] plays for its instrument count: the
  /// two-instrument gap, or the three-instrument one.
  DynamicLadder withGapAt(int index, double db) {
    final id = distanceOf(index).id;
    return instrumentCountAt(index) >= 3
        ? withThreeGap(id, db)
        : withGap(id, db);
  }

  @override
  bool operator ==(Object other) =>
      other is DynamicLadder &&
      other.liftDb == liftDb &&
      _same(other.distances, distances) &&
      _same(other.steps, steps) &&
      HighLowInstrument.values.every(
        (i) => other.headroomOf(i) == headroomOf(i),
      );

  static bool _same(List<Object> a, List<Object> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(distances),
    Object.hashAll(steps),
    liftDb,
    Object.hashAll(HighLowInstrument.values.map(headroomOf)),
  );
}

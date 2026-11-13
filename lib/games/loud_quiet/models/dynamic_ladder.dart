/// Pure Dart (no Flutter import): the curriculum generator, a plain `dart
/// run` script, reads this ladder through curriculum.dart.
library;

import '../../../models/agency_stage.dart';

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

  const DynamicLadder({
    required this.distances,
    required this.steps,
    this.liftDb = 0,
  });

  /// The audibility floor, in dB below full (before trim): the level the
  /// game's quiet sound has always had, never lowered (card 220).
  static const double floorDb = -12;

  /// The ceiling: full. The loudest samples in the pool already peak at
  /// about −1 dBFS (bells, guitar, piano — measured 2026-11-13), so nothing
  /// plays above it.
  static const double ceilingDb = 0;

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

  /// The whole span the levels can use: from [quietDb] up to [ceilingDb].
  double get spanDb => ceilingDb - quietDb;

  /// How far each extra instrument sits beyond the target's nearest
  /// competitor, in dB: small and FIXED. It only has to make that sound
  /// clearly not the answer; how far beyond is irrelevant to the
  /// discrimination, so it spends as little of the span as it can.
  static const double extraOffsetDb = 3;

  /// The widest gap a round of [count] instruments can play: the span, less
  /// what the extra instruments take.
  double maxGapDbFor(int count) =>
      spanDb - (count > 2 ? count - 2 : 0) * extraOffsetDb;

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
  /// instrument. Where that won't fit under [spanDb], the gap is COMPRESSED
  /// to what fits — [isCompressedAt] says so, and the dev gate shows both
  /// figures, so the label never silently lies.
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
  DynamicLadder withGap(String distanceId, double db) => DynamicLadder(
    distances: [
      for (final d in distances)
        d.id == distanceId
            ? d.withGap(db.clamp(minGapDb, maxFigureDb).toDouble())
            : d,
    ],
    steps: steps,
    liftDb: liftDb,
  );

  /// A copy with distance [distanceId]'s THREE-instrument target gap set to
  /// [db], kept within [minGapDb]–[maxFigureDb].
  DynamicLadder withThreeGap(String distanceId, double db) => DynamicLadder(
    distances: [
      for (final d in distances)
        d.id == distanceId
            ? d.withThreeGap(db.clamp(minGapDb, maxFigureDb).toDouble())
            : d,
    ],
    steps: steps,
    liftDb: liftDb,
  );

  /// A copy with the quiet sound lifted [db] above the floor, kept within
  /// 0–[maxLiftDb]. Every gap stays as it is (compressed where the span
  /// above no longer holds it).
  DynamicLadder withLift(double db) => DynamicLadder(
    distances: distances,
    steps: steps,
    liftDb: db.clamp(0, maxLiftDb).toDouble(),
  );

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
      _same(other.steps, steps);

  static bool _same(List<Object> a, List<Object> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(distances), Object.hashAll(steps), liftDb);
}

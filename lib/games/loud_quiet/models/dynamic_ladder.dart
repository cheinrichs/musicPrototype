/// Pure Dart (no Flutter import): the curriculum generator, a plain `dart
/// run` script, reads this ladder through curriculum.dart.
library;

import '../../../models/agency_stage.dart';

/// How far apart the loud and quiet sounds are (Trello card 220), IN
/// DECIBELS — never a gain multiplier. Tunable by ear (the dev gate).
class DynamicDistance {
  final String id;
  final String label;
  final double gapDb;

  const DynamicDistance(this.id, this.label, this.gapDb);

  DynamicDistance withGap(double db) => DynamicDistance(id, label, db);

  @override
  bool operator ==(Object other) =>
      other is DynamicDistance && other.id == id && other.gapDb == gapDb;

  @override
  int get hashCode => Object.hash(id, gapDb);
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

  const DynamicLadder({required this.distances, required this.steps});

  /// The quiet sound's level on every step, in dB below full (before its
  /// instrument's trim): the level the game's quiet sound has always had.
  static const double quietDb = -12;

  /// The widest gap there can be: loud at full. Loud never goes above 0 dB.
  static const double maxGapDb = -quietDb;

  /// The narrowest a gap may be tuned to.
  static const double minGapDb = 1;

  /// The starting table. The dB values are PLACEHOLDERS that happen to be
  /// reasonable; Cooper sets the real ones by ear on a device (the dev
  /// gate's "Gap" control). Expect them to end up unevenly spaced: even in
  /// dB is not even in difficulty, and 8→4 is a far bigger jump than 12→8.
  static const DynamicLadder standard = DynamicLadder(
    distances: [
      DynamicDistance('extreme', 'Extreme', 12),
      DynamicDistance('moderate', 'Moderate', 8),
      DynamicDistance('subtle', 'Subtle', 4),
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

  /// The gap at step [index], in dB.
  double gapDbAt(int index) => distanceOf(index).gapDb;

  /// The loud sound's level at [index], in dB below full (before trim).
  double loudDbAt(int index) => quietDb + gapDbAt(index);

  int instrumentCountAt(int index) => this[index].instrumentCount;

  /// "T1"…: the step's name, 1-based.
  String labelAt(int index) {
    final i = clampIndex(index);
    return 'T${i + 1} ${distanceOf(i).label} ×${steps[i].instrumentCount}';
  }

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
  /// [minGapDb]–[maxGapDb]. Every step at that distance changes with it.
  DynamicLadder withGap(String distanceId, double db) => DynamicLadder(
    distances: [
      for (final d in distances)
        d.id == distanceId
            ? d.withGap(db.clamp(minGapDb, maxGapDb).toDouble())
            : d,
    ],
    steps: steps,
  );

  @override
  bool operator ==(Object other) =>
      other is DynamicLadder &&
      _same(other.distances, distances) &&
      _same(other.steps, steps);

  static bool _same(List<Object> a, List<Object> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(distances), Object.hashAll(steps));
}

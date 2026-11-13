/// Pure Dart (no Flutter import): the curriculum generator, a plain `dart
/// run` script, reads this ladder through curriculum.dart.
library;

/// One step of Loud or Quiet's ladder (Trello card 220).
class DynamicStep {
  final String id;
  final String label;

  /// How far apart the loud and the quiet sound are, IN DECIBELS — never a
  /// gain multiplier (card 220).
  final double gapDb;

  const DynamicStep(this.id, this.label, this.gapDb);

  DynamicStep withGap(double db) => DynamicStep(id, label, db);

  @override
  bool operator ==(Object other) =>
      other is DynamicStep && other.id == id && other.gapDb == gapDb;

  @override
  int get hashCode => Object.hash(id, gapDb);
}

/// Loud or Quiet's own difficulty ladder: DYNAMIC DISTANCE, how far apart
/// the loud and quiet sounds are (card 220). Interval width means nothing
/// for loudness, so it no longer shares High vs Low's eight concept tiers.
///
/// THREE STEPS, as DATA: its length is the table's, never assumed. It may
/// grow later along other dimensions (instrument variety, note count), as
/// High vs Low's did — never through musical context: hearing a dynamic
/// change inside a phrase is its own game, Dynamics (Cooper, 2026-11), not
/// a step of this one. Easiest first.
///
/// The three traps (card 220):
/// - The gap closes by bringing LOUD DOWN toward quiet, never by pushing
///   quiet down: quiet sits at [quietDb] on every step, near enough the
///   speaker's floor already that closing from that end would make the game
///   a hearing test.
/// - Each instrument's trim goes on its BASELINE, before the gap — see
///   `LoudQuietRound.playbackDbOf` — so the gap heard is the step's gap even
///   between two instruments.
/// - Gaps are decibels.
class DynamicLadder {
  final List<DynamicStep> steps;

  const DynamicLadder(this.steps);

  /// The quiet sound's level on every step, in dB below full (before its
  /// instrument's trim): the level the game's quiet sound has always had.
  static const double quietDb = -12;

  /// The widest gap there can be: loud at full. Loud never goes above 0 dB.
  static const double maxGapDb = -quietDb;

  /// The narrowest a gap may be tuned to.
  static const double minGapDb = 1;

  /// The starting table — PLACEHOLDERS that happen to be reasonable; Cooper
  /// sets the real values by ear on a device (the dev gate's Loud/Quiet
  /// "Gap" control). Expect them to end up unevenly spaced: even in dB is
  /// not even in difficulty, and 8→4 is a far bigger jump than 12→8.
  static const DynamicLadder standard = DynamicLadder([
    DynamicStep('extreme', 'Extreme', 12),
    DynamicStep('moderate', 'Moderate', 8),
    DynamicStep('subtle', 'Subtle', 4),
  ]);

  int get length => steps.length;

  /// Step [index], clamped onto the ladder.
  DynamicStep operator [](int index) => steps[clampIndex(index)];

  int clampIndex(int index) => index.clamp(0, length - 1);

  /// The loud sound's level at [index], in dB below full (before trim).
  double loudDbAt(int index) => quietDb + this[index].gapDb;

  /// A copy with step [index]'s gap set to [db], kept within
  /// [minGapDb]–[maxGapDb].
  DynamicLadder withGap(int index, double db) => DynamicLadder([
    for (var i = 0; i < length; i++)
      i == index
          ? steps[i].withGap(db.clamp(minGapDb, maxGapDb).toDouble())
          : steps[i],
  ]);

  @override
  bool operator ==(Object other) =>
      other is DynamicLadder &&
      other.steps.length == steps.length &&
      [
        for (var i = 0; i < steps.length; i++) other.steps[i] == steps[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hashAll(steps);
}

/// How the app says "here is this instrument" with a SHORT sound: "do, do,
/// doo" — three strikes of the same note, a beat apart (Cooper,
/// 2026-11-20). A note that is gone in a tenth of a second is hard to judge
/// from one hearing, so a round's INTRODUCTION plays it three times. A
/// child's own tap still plays it once: they can tap again as often as they
/// like.
///
/// ONE figure for the whole app: the same rhythm is the one to use wherever
/// an instrument is presented this way (Cooper also suggested it for the
/// correct-drop sound).
///
/// WHICH sounds are short is decided by MEASURED duration, never by
/// instrument name, so the drum hits (shorter still) are covered by the
/// same rule; see [strikesFor].
class StrikeFigure {
  StrikeFigure._();

  /// Strikes in the figure for a short sound.
  static const int shortStrikes = 3;

  /// Start to start, between strikes: inside Cooper's 250-300 ms, so the
  /// three take 560 ms to start and well under a second to sound.
  static const Duration spacing = Duration(milliseconds: 280);

  /// A sound whose MEDIAN measured length is under this is short. Lengths
  /// are onset to the last 10 ms block within 20 dB of the peak
  /// (tool/measure_note_decay.py). 400 ms sits in the gap between the
  /// xylophone (median 115 ms, 30-370 ms) and the shortest-ringing real
  /// instrument (the bells, median 590 ms; the flute's is 940 ms).
  static const Duration shortBelow = Duration(milliseconds: 400);

  /// How many times an intro plays a sound whose median length is
  /// [medianLength]: three if short, else one. Unknown length plays once.
  static int strikesFor(Duration? medianLength) =>
      medianLength != null && medianLength < shortBelow ? shortStrikes : 1;

  /// When strike [index] (from 0) starts, after the first.
  static Duration startOf(int index) => spacing * index;
}

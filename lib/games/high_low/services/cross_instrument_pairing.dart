import 'dart:math';
import '../models/high_low_instrument.dart';

/// Picks a valid real-MIDI note pair across two *different* instruments
/// for a cross-instrument High/Low round (Trello, tier T3 — not wired
/// into gameplay yet). [PromptGenerator] still always plays both sides of
/// a round on one instrument today; this is the rule that integration
/// will use once it exists, built and tested ahead of time so the range
/// data this session's pitch audit produced (see
/// `HighLowInstrument`'s class doc) has a real consumer to validate it
/// against.
///
/// The rule (Cooper): two instruments may be paired when their sample
/// ranges overlap by at least the interval a round needs, and the pair
/// must be generated so either instrument could land as the higher note
/// — "tuba means low" should never be a winning strategy on its own.
/// [HighLowInstrument.canPairWith] answers the first half; [generatePair]
/// is the second half, picking uniformly within the overlap so both
/// instruments end up higher roughly equally often across many rounds.
class CrossInstrumentPairing {
  final Random _random;

  CrossInstrumentPairing({Random? random}) : _random = random ?? Random();

  /// Whether [a] and [b] share enough range to produce a pair at least
  /// [minSemitones] apart. Thin wrapper around
  /// [HighLowInstrument.canPairWith] — the natural check to run before
  /// [generatePair], which throws if it isn't satisfied.
  bool instrumentsCanPair(
    HighLowInstrument a,
    HighLowInstrument b, {
    required int minSemitones,
  }) => a.canPairWith(b, minSemitones: minSemitones);

  /// Generates a note pair across [a] and [b], [minSemitones]..
  /// [maxSemitones] apart, with either instrument equally likely to be
  /// the higher one. Throws a [StateError] if [a] and [b] don't overlap
  /// by at least [minSemitones] — call [instrumentsCanPair] first.
  ({int aMidi, int bMidi}) generatePair(
    HighLowInstrument a,
    HighLowInstrument b, {
    required int minSemitones,
    required int maxSemitones,
  }) {
    final overlapLow = max(a.lowestSampleMidi, b.lowestSampleMidi);
    final overlapHigh = min(a.highestSampleMidi, b.highestSampleMidi);
    final overlapSpan = overlapHigh - overlapLow;
    if (overlapSpan < minSemitones) {
      throw StateError(
        '${a.name} and ${b.name} only overlap by $overlapSpan semitones, '
        'less than the requested minimum of $minSemitones — check '
        'instrumentsCanPair first.',
      );
    }

    // Same interval-first approach as PromptGenerator, over the overlap
    // window instead of a single instrument's own range: pick the gap
    // before either note, capped at the window's full span, so there's
    // always a valid placement no matter how narrow the overlap is.
    final effectiveMax = min(maxSemitones, overlapSpan);
    final effectiveMin = min(minSemitones, effectiveMax);
    final interval =
        _random.nextInt(effectiveMax - effectiveMin + 1) + effectiveMin;

    final maxLowOffset = overlapSpan - interval;
    final lowOffset = _random.nextInt(maxLowOffset + 1);
    final lowMidi = overlapLow + lowOffset;
    final highMidi = lowMidi + interval;

    final aIsHigher = _random.nextBool();
    return aIsHigher
        ? (aMidi: highMidi, bMidi: lowMidi)
        : (aMidi: lowMidi, bMidi: highMidi);
  }
}

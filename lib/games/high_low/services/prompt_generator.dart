import 'dart:math';
import '../../../models/concept_tier.dart';
import '../../../models/pitch_direction.dart';
import '../models/high_low_instrument.dart';
import '../models/high_low_prompt.dart';

/// Generates prompts (note pairs) for the High/Low game, sized by
/// [ConceptTier] (Trello card 95) rather than a raw difficulty number —
/// see [ConceptTier] for what each tier controls.
class PromptGenerator {
  final Random _random;

  PromptGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a full session's worth of prompts. [targetDirections] must
  /// have length [count] — one target direction per round, typically from
  /// [RoundSequencer].
  List<HighLowPrompt> generatePrompts({
    required int count,
    required ConceptTier tier,
    required List<PitchDirection> targetDirections,
  }) {
    assert(targetDirections.length == count);
    return List.generate(
      count,
      (index) => generatePrompt(
        promptNumber: index + 1,
        tier: tier,
        targetDirection: targetDirections[index],
      ),
    );
  }

  /// Generate a single prompt for the given [tier].
  HighLowPrompt generatePrompt({
    required int promptNumber,
    required ConceptTier tier,
    required PitchDirection targetDirection,
  }) {
    // Both sides of a round always share one instrument (Cooper: "i don't
    // think we'll be pitting different instruments against each other ever
    // and comparing pitch") — timbre varies *between* rounds instead, by
    // this pick happening fresh per prompt.
    final instrumentValues = HighLowInstrument.values;
    final instrument =
        instrumentValues[_random.nextInt(instrumentValues.length)];

    // Notes are picked as real MIDI pitches directly from *this*
    // instrument's own available notes (HighLowInstrument.availableMidis)
    // — not every instrument's range is a full two octaves, and guitar's
    // isn't even gap-free within its declared range (see the class doc).
    // Enumerating every pair of available notes and filtering by interval,
    // rather than picking an interval first and reaching outward by a raw
    // offset, is what makes gaps safe: a raw-offset approach can land
    // exactly on a missing note (guitar has two) and request a sample
    // that doesn't exist. The instrument list is short enough (at most
    // two octaves) that enumerating every pair is cheap.
    final available = instrument.availableMidis;
    final span = available.last - available.first;

    final minInterval = min(tier.minSemitones, span);
    final maxInterval = min(tier.maxSemitones, span);

    final validPairs = <({int low, int high})>[
      for (final low in available)
        for (final high in available)
          if (high - low >= minInterval && high - low <= maxInterval)
            (low: low, high: high),
    ];
    final pair = validPairs[_random.nextInt(validPairs.length)];

    // Randomly decide which side gets the higher pitch — must stay a coin
    // flip, or the child learns position instead of pitch.
    final firstIsHigher = _random.nextBool();
    final firstMidi = firstIsHigher ? pair.high : pair.low;
    final secondMidi = firstIsHigher ? pair.low : pair.high;

    return HighLowPrompt(
      firstMidi: firstMidi,
      secondMidi: secondMidi,
      firstInstrument: instrument,
      secondInstrument: instrument,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

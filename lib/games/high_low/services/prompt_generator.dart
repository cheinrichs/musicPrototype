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

    // Notes are picked as real MIDI pitches directly within *this*
    // instrument's own declared range (HighLowInstrument.lowestSampleMidi
    // .. highestSampleMidi) — that range isn't always two full octaves any
    // more (see the class doc: guitar and tuba currently have gaps that
    // shrink it well below that). Picking the interval *before* either
    // note, rather than picking a first note and then reaching outward
    // from it, guarantees the requested interval always fits regardless
    // of how narrow the range is: cap the interval at the range's full
    // span, then there's always at least one valid placement for it.
    final lowestMidi = instrument.lowestSampleMidi;
    final span = instrument.highestSampleMidi - lowestMidi;

    final minInterval = min(tier.minSemitones, span);
    final maxInterval = min(tier.maxSemitones, span);
    final interval =
        _random.nextInt(maxInterval - minInterval + 1) + minInterval;

    final maxLowOffset = span - interval;
    final lowOffset = _random.nextInt(maxLowOffset + 1);
    final highOffset = lowOffset + interval;

    // Randomly decide which side gets the higher pitch — must stay a coin
    // flip, or the child learns position instead of pitch.
    final firstIsHigher = _random.nextBool();
    final firstOffset = firstIsHigher ? highOffset : lowOffset;
    final secondOffset = firstIsHigher ? lowOffset : highOffset;

    return HighLowPrompt(
      firstMidi: lowestMidi + firstOffset,
      secondMidi: lowestMidi + secondOffset,
      firstInstrument: instrument,
      secondInstrument: instrument,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

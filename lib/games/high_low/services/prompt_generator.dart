import 'dart:math';
import '../../../audio/note.dart';
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
    final minInterval = tier.minSemitones;
    final maxInterval = tier.maxSemitones;

    // Pick a random first note (avoiding extremes to allow room for interval)
    final availableNotes = Note.values;
    final maxFirstNoteIndex = availableNotes.length - minInterval - 1;
    final minFirstNoteIndex = minInterval;

    final firstNoteIndex =
        _random.nextInt(maxFirstNoteIndex - minFirstNoteIndex + 1) +
        minFirstNoteIndex;
    final firstNote = availableNotes[firstNoteIndex];

    // Calculate the interval
    final interval =
        _random.nextInt(maxInterval - minInterval + 1) + minInterval;

    // Randomly decide if going up or down — this is what randomizes which
    // side ends up with the higher note (must stay a coin flip, or the
    // child learns position instead of pitch).
    final goingUp = _random.nextBool();

    // Calculate second note index
    int secondNoteIndex;
    if (goingUp) {
      secondNoteIndex = firstNoteIndex + interval;
      // Clamp to valid range
      if (secondNoteIndex >= availableNotes.length) {
        secondNoteIndex = firstNoteIndex - interval;
      }
    } else {
      secondNoteIndex = firstNoteIndex - interval;
      // Clamp to valid range
      if (secondNoteIndex < 0) {
        secondNoteIndex = firstNoteIndex + interval;
      }
    }

    // Ensure second note index is valid
    secondNoteIndex = secondNoteIndex.clamp(0, availableNotes.length - 1);

    // Make sure the notes are different
    if (secondNoteIndex == firstNoteIndex) {
      secondNoteIndex = (firstNoteIndex + minInterval).clamp(
        0,
        availableNotes.length - 1,
      );
    }

    final secondNote = availableNotes[secondNoteIndex];

    // Both sides of a round always share one instrument (Cooper: "i don't
    // think we'll be pitting different instruments against each other ever
    // and comparing pitch") — timbre varies *between* rounds instead, by
    // this pick happening fresh per prompt.
    final instrumentValues = HighLowInstrument.values;
    final instrument =
        instrumentValues[_random.nextInt(instrumentValues.length)];

    return HighLowPrompt(
      firstNote: firstNote,
      secondNote: secondNote,
      firstInstrument: instrument,
      secondInstrument: instrument,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

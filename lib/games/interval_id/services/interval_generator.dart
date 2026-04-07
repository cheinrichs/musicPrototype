import 'dart:math';
import '../../../audio/note.dart';
import '../../../models/interval_type.dart';
import '../models/interval_prompt.dart';

/// Generates prompts for the Interval Identification game
class IntervalGenerator {
  final Random _random;

  IntervalGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<IntervalPrompt> generatePrompts({int count = 10}) {
    return List.generate(
      count,
      (index) => generatePrompt(promptNumber: index + 1),
    );
  }

  /// Generate a single interval prompt
  IntervalPrompt generatePrompt({required int promptNumber}) {
    // Pick a random interval type
    final intervalTypes = IntervalType.values;
    final intervalType = intervalTypes[_random.nextInt(intervalTypes.length)];

    // Pick a root note that allows the interval to fit within our range
    // Note range is C4 (index 0) to B5 (index 23)
    final allNotes = Note.values;
    final maxRootIndex = allNotes.length - 1 - intervalType.semitones;
    final rootIndex = _random.nextInt(maxRootIndex + 1);
    final rootNote = allNotes[rootIndex];

    // Calculate second note
    final secondNoteIndex = rootIndex + intervalType.semitones;
    final secondNote = allNotes[secondNoteIndex];

    return IntervalPrompt(
      rootNote: rootNote,
      secondNote: secondNote,
      intervalType: intervalType,
      promptNumber: promptNumber,
    );
  }
}

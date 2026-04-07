import 'dart:math';
import '../../../audio/note.dart';
import '../../../models/chord_type.dart';
import '../models/chord_prompt.dart';

/// Generates prompts for the Chord Identification game
class ChordGenerator {
  final Random _random;

  ChordGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<ChordPrompt> generatePrompts({int count = 10}) {
    return List.generate(
      count,
      (index) => generatePrompt(promptNumber: index + 1),
    );
  }

  /// Generate a single chord prompt
  ChordPrompt generatePrompt({required int promptNumber}) {
    // Pick a random chord type
    final chordTypes = ChordType.values;
    final chordType = chordTypes[_random.nextInt(chordTypes.length)];

    // Pick a root note that allows the chord to fit within our range
    // Note range is C4 (index 0) to B5 (index 23)
    // Need room for perfect 5th (7 semitones)
    final allNotes = Note.values;
    final maxRootIndex = allNotes.length - 1 - 7; // 7 semitones for P5
    final rootIndex = _random.nextInt(maxRootIndex + 1);
    final rootNote = allNotes[rootIndex];

    // Build chord notes based on chord type
    final chordNotes = _buildChord(rootNote, chordType);

    return ChordPrompt(
      rootNote: rootNote,
      chordNotes: chordNotes,
      chordType: chordType,
      promptNumber: promptNumber,
    );
  }

  /// Build chord notes from root and chord type
  List<Note> _buildChord(Note root, ChordType chordType) {
    final allNotes = Note.values;
    final rootIndex = allNotes.indexOf(root);
    final intervals = chordType.intervals;

    final notes = <Note>[root];
    for (final interval in intervals) {
      final noteIndex = rootIndex + interval;
      if (noteIndex < allNotes.length) {
        notes.add(allNotes[noteIndex]);
      }
    }

    return notes;
  }
}

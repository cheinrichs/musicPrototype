import 'dart:math';
import '../../../audio/note.dart';
import '../../../models/scale_direction.dart';
import '../models/scale_direction_prompt.dart';

/// Generates scale prompts for the Scale Direction game
class ScaleGenerator {
  final Random _random;

  /// First 3 notes of a major scale: root, major 2nd, major 3rd
  static const List<int> majorScaleIntervals = [0, 2, 4];

  ScaleGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<ScaleDirectionPrompt> generatePrompts({int count = 10}) {
    return List.generate(
      count,
      (index) => generatePrompt(promptNumber: index + 1),
    );
  }

  /// Generate a single scale prompt
  ScaleDirectionPrompt generatePrompt({required int promptNumber}) {
    // Randomly choose direction
    final direction = _random.nextBool()
        ? ScaleDirection.ascending
        : ScaleDirection.descending;

    // Generate scale based on direction
    final scaleNotes = _generateMajorScale(direction);

    return ScaleDirectionPrompt(
      scaleNotes: scaleNotes,
      direction: direction,
      promptNumber: promptNumber,
    );
  }

  List<Note> _generateMajorScale(ScaleDirection direction) {
    final allNotes = Note.values;

    if (direction == ScaleDirection.ascending) {
      // For ascending, start note must allow 12 semitones up
      // Valid indices: 0-11 (C4 to B4)
      final maxStartIndex = allNotes.length - 13; // 24 - 13 = 11
      final startIndex = _random.nextInt(maxStartIndex + 1);
      final startNote = allNotes[startIndex];

      return _buildAscendingScale(startNote);
    } else {
      // For descending, start note must allow 12 semitones down
      // Valid indices: 12-23 (C5 to B5)
      final minStartIndex = 12;
      final startIndex =
          _random.nextInt(allNotes.length - minStartIndex) + minStartIndex;
      final startNote = allNotes[startIndex];

      return _buildDescendingScale(startNote);
    }
  }

  List<Note> _buildAscendingScale(Note startNote) {
    final startMidi = startNote.midiNumber;
    final notes = <Note>[];

    for (final interval in majorScaleIntervals) {
      final targetMidi = startMidi + interval;
      final note = NoteExtension.fromMidiNumber(targetMidi);
      if (note != null) {
        notes.add(note);
      }
    }

    return notes;
  }

  List<Note> _buildDescendingScale(Note startNote) {
    final startMidi = startNote.midiNumber;
    final notes = <Note>[];

    for (final interval in majorScaleIntervals) {
      final targetMidi = startMidi - interval;
      final note = NoteExtension.fromMidiNumber(targetMidi);
      if (note != null) {
        notes.add(note);
      }
    }

    return notes;
  }
}

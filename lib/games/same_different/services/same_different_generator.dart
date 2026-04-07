import 'dart:math';
import '../../../audio/note.dart';
import '../models/same_different_prompt.dart';

/// Generates prompts for the Same or Different game
class SameDifferentGenerator {
  final Random _random;
  final int melodyLength;

  SameDifferentGenerator({Random? random, this.melodyLength = 3})
    : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<SameDifferentPrompt> generatePrompts({int count = 10}) {
    return List.generate(
      count,
      (index) => generatePrompt(promptNumber: index + 1),
    );
  }

  /// Generate a single prompt
  SameDifferentPrompt generatePrompt({required int promptNumber}) {
    // Randomly decide if melodies will be same or different
    final areSame = _random.nextBool();

    // Generate the first melody
    final firstMelody = _generateMelody();

    // Generate second melody (same or with one note changed)
    final secondMelody = areSame
        ? List<Note>.from(firstMelody)
        : _changeOneNote(firstMelody);

    return SameDifferentPrompt(
      firstMelody: firstMelody,
      secondMelody: secondMelody,
      areSame: areSame,
      promptNumber: promptNumber,
    );
  }

  /// Generate a random melody of the specified length
  List<Note> _generateMelody() {
    final allNotes = Note.values;
    final melody = <Note>[];

    for (int i = 0; i < melodyLength; i++) {
      // Pick a random note, but try to keep it melodic
      // (not too far from the previous note)
      if (melody.isEmpty) {
        // Start somewhere in the middle of the range
        final startIndex =
            allNotes.length ~/ 4 + _random.nextInt(allNotes.length ~/ 2);
        melody.add(allNotes[startIndex]);
      } else {
        // Pick a note within 5 semitones of the previous note
        final prevIndex = allNotes.indexOf(melody.last);
        final minIndex = (prevIndex - 5).clamp(0, allNotes.length - 1);
        final maxIndex = (prevIndex + 5).clamp(0, allNotes.length - 1);
        final range = maxIndex - minIndex + 1;
        final newIndex = minIndex + _random.nextInt(range);
        melody.add(allNotes[newIndex]);
      }
    }

    return melody;
  }

  /// Change one random note in the melody to create a "different" version
  List<Note> _changeOneNote(List<Note> original) {
    final modified = List<Note>.from(original);
    final allNotes = Note.values;

    // Pick a random position to change
    final changeIndex = _random.nextInt(modified.length);
    final originalNote = modified[changeIndex];
    final originalNoteIndex = allNotes.indexOf(originalNote);

    // Change by 1-3 semitones up or down (noticeable but not huge)
    final direction = _random.nextBool() ? 1 : -1;
    final semitones = 1 + _random.nextInt(3); // 1, 2, or 3 semitones
    var newNoteIndex = originalNoteIndex + (direction * semitones);

    // Keep within bounds
    newNoteIndex = newNoteIndex.clamp(0, allNotes.length - 1);

    // Make sure it's actually different
    if (newNoteIndex == originalNoteIndex) {
      newNoteIndex = (originalNoteIndex + 2).clamp(0, allNotes.length - 1);
    }

    modified[changeIndex] = allNotes[newNoteIndex];
    return modified;
  }
}

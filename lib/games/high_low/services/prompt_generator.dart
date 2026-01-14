import 'dart:math';
import '../../../audio/note.dart';
import '../models/high_low_prompt.dart';

/// Generates prompts for the High/Low game with difficulty scaling
class PromptGenerator {
  final Random _random;

  /// Minimum semitone distance between notes (easiest to distinguish)
  static const int minSemitoneDistance = 2;

  /// Maximum semitone distance (a full octave)
  static const int maxSemitoneDistance = 12;

  PromptGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<HighLowPrompt> generatePrompts({int count = 10, int difficulty = 1}) {
    return List.generate(
      count,
      (index) =>
          generatePrompt(promptNumber: index + 1, difficulty: difficulty),
    );
  }

  /// Generate a single prompt with the given difficulty
  /// Difficulty 1-5: 1 = easy (large intervals), 5 = hard (small intervals)
  HighLowPrompt generatePrompt({
    required int promptNumber,
    int difficulty = 1,
  }) {
    // Clamp difficulty to valid range
    final clampedDifficulty = difficulty.clamp(1, 5);

    // Calculate interval range based on difficulty
    // Level 1: 7-12 semitones (perfect 5th to octave)
    // Level 5: 2-4 semitones (major 2nd to major 3rd)
    final minInterval = _getMinInterval(clampedDifficulty);
    final maxInterval = _getMaxInterval(clampedDifficulty);

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

    // Randomly decide if going up or down
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

    return HighLowPrompt(
      firstNote: firstNote,
      secondNote: secondNote,
      promptNumber: promptNumber,
    );
  }

  int _getMinInterval(int difficulty) {
    switch (difficulty) {
      case 1:
        return 7; // Perfect 5th
      case 2:
        return 5; // Perfect 4th
      case 3:
        return 4; // Major 3rd
      case 4:
        return 3; // Minor 3rd
      case 5:
        return 2; // Major 2nd
      default:
        return 5;
    }
  }

  int _getMaxInterval(int difficulty) {
    switch (difficulty) {
      case 1:
        return 12; // Octave
      case 2:
        return 10; // Minor 7th
      case 3:
        return 7; // Perfect 5th
      case 4:
        return 5; // Perfect 4th
      case 5:
        return 4; // Major 3rd
      default:
        return 8;
    }
  }
}

import 'dart:math';
import '../../../audio/note.dart';
import '../models/match_note_prompt.dart';

/// Generates prompts for the Match the Note game
class MatchNoteGenerator {
  final Random _random;

  MatchNoteGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a list of prompts for a game session
  List<MatchNotePrompt> generatePrompts({int count = 10, int difficulty = 1}) {
    return List.generate(
      count,
      (index) =>
          generatePrompt(promptNumber: index + 1, difficulty: difficulty),
    );
  }

  /// Generate a single prompt with 3 choices
  MatchNotePrompt generatePrompt({
    required int promptNumber,
    int difficulty = 1,
  }) {
    final allNotes = Note.values;

    // Pick a random target note (avoid edges to have room for wrong choices)
    final minInterval = _getMinInterval(difficulty);
    final margin = minInterval * 2;
    final targetIndex = _random.nextInt(allNotes.length - margin * 2) + margin;
    final targetNote = allNotes[targetIndex];

    // Generate 2 wrong choices at appropriate intervals
    final wrongChoices = _generateWrongChoices(targetIndex, difficulty);

    // Create choices list with target at random position
    final correctIndex = _random.nextInt(3);
    final choices = <Note>[];

    int wrongIndex = 0;
    for (int i = 0; i < 3; i++) {
      if (i == correctIndex) {
        choices.add(targetNote);
      } else {
        choices.add(wrongChoices[wrongIndex]);
        wrongIndex++;
      }
    }

    return MatchNotePrompt(
      targetNote: targetNote,
      choices: choices,
      correctIndex: correctIndex,
      promptNumber: promptNumber,
    );
  }

  /// Get minimum interval between choices based on difficulty
  /// Higher difficulty = closer notes = harder to distinguish
  int _getMinInterval(int difficulty) {
    switch (difficulty) {
      case 1:
        return 4; // Easy: at least 4 semitones apart
      case 2:
        return 3; // Medium: at least 3 semitones apart
      case 3:
        return 2; // Hard: at least 2 semitones apart
      case 4:
      case 5:
        return 1; // Very hard: can be adjacent semitones
      default:
        return 4;
    }
  }

  /// Generate 2 wrong choices that are distinct from target and each other
  List<Note> _generateWrongChoices(int targetIndex, int difficulty) {
    final allNotes = Note.values;
    final minInterval = _getMinInterval(difficulty);
    final maxInterval = minInterval + 3;

    final wrongChoices = <Note>[];
    final usedIndices = <int>{targetIndex};

    // Generate first wrong choice (below or above target)
    final goBelow = _random.nextBool();
    int firstWrongIndex;
    if (goBelow && targetIndex >= minInterval) {
      firstWrongIndex =
          targetIndex -
          minInterval -
          _random.nextInt(maxInterval - minInterval + 1);
      firstWrongIndex = firstWrongIndex.clamp(0, allNotes.length - 1);
    } else if (targetIndex + minInterval < allNotes.length) {
      firstWrongIndex =
          targetIndex +
          minInterval +
          _random.nextInt(maxInterval - minInterval + 1);
      firstWrongIndex = firstWrongIndex.clamp(0, allNotes.length - 1);
    } else {
      firstWrongIndex =
          targetIndex -
          minInterval -
          _random.nextInt(maxInterval - minInterval + 1);
      firstWrongIndex = firstWrongIndex.clamp(0, allNotes.length - 1);
    }

    wrongChoices.add(allNotes[firstWrongIndex]);
    usedIndices.add(firstWrongIndex);

    // Generate second wrong choice (opposite direction from first)
    int secondWrongIndex;
    if (firstWrongIndex < targetIndex &&
        targetIndex + minInterval < allNotes.length) {
      // First was below, put second above
      secondWrongIndex =
          targetIndex +
          minInterval +
          _random.nextInt(maxInterval - minInterval + 1);
    } else if (firstWrongIndex > targetIndex && targetIndex >= minInterval) {
      // First was above, put second below
      secondWrongIndex =
          targetIndex -
          minInterval -
          _random.nextInt(maxInterval - minInterval + 1);
    } else {
      // Same side as first but different interval
      final offset =
          minInterval + 1 + _random.nextInt(maxInterval - minInterval);
      secondWrongIndex = firstWrongIndex < targetIndex
          ? targetIndex - offset
          : targetIndex + offset;
    }

    secondWrongIndex = secondWrongIndex.clamp(0, allNotes.length - 1);

    // Ensure second choice is different from first and target
    while (usedIndices.contains(secondWrongIndex)) {
      secondWrongIndex = (secondWrongIndex + 1) % allNotes.length;
    }

    wrongChoices.add(allNotes[secondWrongIndex]);

    return wrongChoices;
  }
}

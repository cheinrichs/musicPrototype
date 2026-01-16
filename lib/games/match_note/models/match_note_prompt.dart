import '../../../audio/note.dart';

/// A single prompt in the Match the Note game
/// Contains a target note and 3 choices (one of which is the target)
class MatchNotePrompt {
  final Note targetNote;
  final List<Note> choices;
  final int correctIndex;
  final int promptNumber;

  const MatchNotePrompt({
    required this.targetNote,
    required this.choices,
    required this.correctIndex,
    required this.promptNumber,
  });

  /// The correct answer for this prompt
  Note get correctAnswer => targetNote;

  /// Check if the user's choice index is correct
  bool isCorrect(int choiceIndex) => choiceIndex == correctIndex;

  /// Get the note at a given choice index
  Note getChoice(int index) => choices[index];

  /// Number of choices (always 3)
  int get choiceCount => choices.length;
}

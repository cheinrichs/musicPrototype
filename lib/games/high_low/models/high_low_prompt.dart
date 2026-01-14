import '../../../audio/note.dart';
import '../../../models/pitch_direction.dart';

/// A single prompt in the High/Low game
/// Contains two notes and the user needs to determine if the second is higher or lower
class HighLowPrompt {
  final Note firstNote;
  final Note secondNote;
  final int promptNumber;

  const HighLowPrompt({
    required this.firstNote,
    required this.secondNote,
    required this.promptNumber,
  });

  /// The correct answer for this prompt
  PitchDirection get correctAnswer => secondNote.isHigherThan(firstNote)
      ? PitchDirection.higher
      : PitchDirection.lower;

  /// The difficulty level based on semitone distance
  /// Smaller intervals are harder to distinguish
  int get difficulty => firstNote.intervalTo(secondNote);

  /// Check if the user's answer is correct
  bool isCorrect(PitchDirection answer) => answer == correctAnswer;
}

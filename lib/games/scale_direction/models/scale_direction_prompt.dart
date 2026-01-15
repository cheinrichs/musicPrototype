import '../../../audio/note.dart';
import '../../../models/scale_direction.dart';

/// A single prompt in the Scale Direction game
/// Contains a major scale (8 notes) and the direction it's played
class ScaleDirectionPrompt {
  final List<Note> scaleNotes;
  final ScaleDirection direction;
  final int promptNumber;

  const ScaleDirectionPrompt({
    required this.scaleNotes,
    required this.direction,
    required this.promptNumber,
  });

  /// The correct answer for this prompt
  ScaleDirection get correctAnswer => direction;

  /// Check if the user's answer is correct
  bool isCorrect(ScaleDirection answer) => answer == correctAnswer;

  /// The root note of the scale
  Note get rootNote => scaleNotes.first;

  /// Number of notes in the scale
  int get noteCount => scaleNotes.length;
}

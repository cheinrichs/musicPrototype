import '../../../audio/note.dart';
import '../../../models/interval_type.dart';

/// A single prompt in the Interval Identification game
/// Contains two notes forming an interval
class IntervalPrompt {
  final Note rootNote;
  final Note secondNote;
  final IntervalType intervalType;
  final int promptNumber;

  const IntervalPrompt({
    required this.rootNote,
    required this.secondNote,
    required this.intervalType,
    required this.promptNumber,
  });

  /// The correct answer for this prompt
  IntervalType get correctAnswer => intervalType;

  /// Check if the user's answer is correct
  bool isCorrect(IntervalType answer) => answer == correctAnswer;

  /// The interval in semitones
  int get semitones => intervalType.semitones;
}

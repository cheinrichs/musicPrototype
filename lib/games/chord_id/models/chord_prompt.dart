import '../../../audio/note.dart';
import '../../../models/chord_type.dart';

/// A single prompt in the Chord Identification game
/// Contains notes forming a chord (major or minor)
class ChordPrompt {
  final Note rootNote;
  final List<Note> chordNotes;
  final ChordType chordType;
  final int promptNumber;

  const ChordPrompt({
    required this.rootNote,
    required this.chordNotes,
    required this.chordType,
    required this.promptNumber,
  });

  /// The correct answer for this prompt
  ChordType get correctAnswer => chordType;

  /// Check if the user's answer is correct
  bool isCorrect(ChordType answer) => answer == correctAnswer;
}

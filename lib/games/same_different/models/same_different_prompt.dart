import '../../../audio/note.dart';

/// A single prompt in the Same or Different game
/// Contains two melodies - either identical or with one note changed
class SameDifferentPrompt {
  final List<Note> firstMelody;
  final List<Note> secondMelody;
  final bool areSame;
  final int promptNumber;

  const SameDifferentPrompt({
    required this.firstMelody,
    required this.secondMelody,
    required this.areSame,
    required this.promptNumber,
  });

  /// Check if the user's answer is correct
  bool isCorrect(bool userSaidSame) => userSaidSame == areSame;

  /// Number of notes in each melody
  int get melodyLength => firstMelody.length;
}

import '../../../audio/note.dart';
import '../../../models/pitch_direction.dart';

/// A single round of the High/Low game: two notes, plus which direction
/// (high or low) the round is actually asking about.
///
/// [correctAnswer] and [targetDirection] both use [PitchDirection] but mean
/// different things: [correctAnswer] is a fact about the *stimulus* (which
/// of the two notes is higher), while [targetDirection] is a fact about the
/// *question* (which one the child is asked to find this round — a
/// property of round sequencing, not of the stimulus; see RoundOrder).
/// Observe (A0) rounds don't ask anything, so they generate a prompt too
/// but simply ignore [targetDirection].
class HighLowPrompt {
  /// Plays on the left instrument.
  final Note firstNote;

  /// Plays on the right instrument.
  final Note secondNote;

  final int promptNumber;
  final PitchDirection targetDirection;

  const HighLowPrompt({
    required this.firstNote,
    required this.secondNote,
    required this.promptNumber,
    required this.targetDirection,
  });

  /// Whether the second note (right instrument) is the higher of the two.
  PitchDirection get correctAnswer => secondNote.isHigherThan(firstNote)
      ? PitchDirection.higher
      : PitchDirection.lower;

  /// Semitone distance between the two notes.
  int get difficulty => firstNote.intervalTo(secondNote);

  /// True when the left (first-played) instrument is the higher one.
  bool get leftIsHigher => firstNote.isHigherThan(secondNote);

  /// 0 (left) or 1 (right) — whichever side is actually higher.
  int get higherSide => leftIsHigher ? 0 : 1;

  /// 0 (left) or 1 (right) — the side that answers [targetDirection] for
  /// this round (e.g. the low side, if this round is asking "which one is
  /// low?").
  int get targetSide =>
      targetDirection == PitchDirection.higher ? higherSide : 1 - higherSide;

  /// Check if the user's answer is correct (used by stages that ask
  /// "higher or lower", independent of [targetDirection]).
  bool isCorrect(PitchDirection answer) => answer == correctAnswer;
}

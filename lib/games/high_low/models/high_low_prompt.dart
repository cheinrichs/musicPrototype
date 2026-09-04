import '../../../models/pitch_direction.dart';
import 'high_low_instrument.dart';

/// A single round of the High/Low game: two notes, plus which direction
/// (high or low) the round is actually asking about.
///
/// [firstMidi]/[secondMidi] are real sounding MIDI pitches — whatever
/// [firstInstrument]/[secondInstrument]'s own sample actually plays at, no
/// separate "logical" number to translate through (see
/// [HighLowInstrument]'s class doc for why that translation used to exist
/// and was retired). [correctAnswer] is therefore a direct, un-adjusted
/// comparison of the two.
///
/// [correctAnswer] and [targetDirection] both use [PitchDirection] but mean
/// different things: [correctAnswer] is a fact about the *stimulus* (which
/// of the two notes is higher), while [targetDirection] is a fact about the
/// *question* (which one the child is asked to find this round — a
/// property of round sequencing, not of the stimulus; see RoundOrder).
/// Observe (A0) rounds don't ask anything, so they generate a prompt too
/// but simply ignore [targetDirection].
///
/// A round is always two notes on the *same* instrument today (Cooper: "i
/// don't think we'll be pitting different instruments against each other
/// ever and comparing pitch") — [firstInstrument] and [secondInstrument]
/// are asserted equal below rather than collapsed into one field, so nothing
/// else here has to assume they match. That decision is being revisited for
/// a future cross-instrument round (tier T3): see
/// [HighLowInstrument.canPairWith] for the pairing rule it would use, built
/// but not yet wired in here — this assertion still holds until it is.
class HighLowPrompt {
  /// Real sounding MIDI pitch played on the left ([firstInstrument]).
  final int firstMidi;

  /// Real sounding MIDI pitch played on the right ([secondInstrument]).
  final int secondMidi;

  /// Instrument the left side ([firstMidi]) sounds on.
  final HighLowInstrument firstInstrument;

  /// Instrument the right side ([secondMidi]) sounds on. Always equal to
  /// [firstInstrument] today — see the class doc.
  final HighLowInstrument secondInstrument;

  final int promptNumber;
  final PitchDirection targetDirection;

  const HighLowPrompt({
    required this.firstMidi,
    required this.secondMidi,
    required this.firstInstrument,
    required this.secondInstrument,
    required this.promptNumber,
    required this.targetDirection,
  }) : assert(
         firstInstrument == secondInstrument,
         'A High/Low round is always two notes on the same instrument — '
         'got $firstInstrument vs $secondInstrument.',
       );

  /// Whether the second note (right instrument) is the higher of the two,
  /// by real sounding pitch.
  PitchDirection get correctAnswer =>
      secondMidi > firstMidi ? PitchDirection.higher : PitchDirection.lower;

  /// Semitone distance between the two notes.
  int get difficulty => (secondMidi - firstMidi).abs();

  /// True when the left (first-played) instrument is the higher one.
  bool get leftIsHigher => firstMidi > secondMidi;

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

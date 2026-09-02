import '../../../audio/note.dart';
import '../../../models/pitch_direction.dart';
import 'high_low_instrument.dart';

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
///
/// A round is always two notes on the *same* instrument (Cooper: "i don't
/// think we'll be pitting different instruments against each other ever
/// and comparing pitch") — [firstInstrument] and [secondInstrument] are
/// asserted equal below rather than collapsed into one field, so
/// [correctAnswer] can stay written in terms of each side's own real
/// sounding pitch instead of assuming they match.
class HighLowPrompt {
  /// Plays on the left instrument.
  final Note firstNote;

  /// Plays on the right instrument.
  final Note secondNote;

  /// Instrument the left side ([firstNote]) sounds on.
  final HighLowInstrument firstInstrument;

  /// Instrument the right side ([secondNote]) sounds on. Always equal to
  /// [firstInstrument] — see the class doc.
  final HighLowInstrument secondInstrument;

  final int promptNumber;
  final PitchDirection targetDirection;

  const HighLowPrompt({
    required this.firstNote,
    required this.secondNote,
    required this.firstInstrument,
    required this.secondInstrument,
    required this.promptNumber,
    required this.targetDirection,
  }) : assert(
         firstInstrument == secondInstrument,
         'A High/Low round is always two notes on the same instrument — '
         'got $firstInstrument vs $secondInstrument.',
       );

  /// Real sounding MIDI number of [firstNote], accounting for
  /// [firstInstrument]'s transposition (see
  /// [HighLowInstrument.realPitchOffsetSemitones]).
  int get _firstRealMidiNumber =>
      firstNote.midiNumber + firstInstrument.realPitchOffsetSemitones;

  /// Real sounding MIDI number of [secondNote] — see [_firstRealMidiNumber].
  int get _secondRealMidiNumber =>
      secondNote.midiNumber + secondInstrument.realPitchOffsetSemitones;

  /// Whether the second note (right instrument) is the higher of the two,
  /// by real sounding pitch rather than logical note slot — equivalent
  /// today since both sides always share an instrument (so any
  /// transposition cancels out), but correct even if that ever changes.
  PitchDirection get correctAnswer =>
      _secondRealMidiNumber > _firstRealMidiNumber
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

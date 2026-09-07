import '../../../models/pitch_direction.dart';
import 'high_low_instrument.dart';

/// A single round of the High/Low game: two or three notes, plus which
/// direction (high or low) the round is actually asking about.
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
/// [firstInstrument] and [secondInstrument] are the same instrument for a
/// same-instrument tier (`ConceptTier.instrumentsVary` false), and two
/// different, pairable instruments (see [HighLowInstrument.canPairWith])
/// for a cross-instrument tier — this replaced an earlier, permanent
/// assertion that they always matched, back when every High/Low round was
/// two notes on one instrument (Trello card "Rebuild the tier ladder as
/// eight tiers (2x2x2)"; see `docs/product/HIGH_LOW_TIERS.md`'s overlap
/// rule for how [PromptGenerator] picks a legal cross-instrument pair).
///
/// [thirdMidi]/[thirdInstrument] are non-null exactly for a three-note
/// tier's prompt (`ConceptTier.noteCount` 3) — see [isThreeNote] and
/// [highestIndex]. No screen renders a three-note round yet; this only
/// exists so [PromptGenerator] and this model can be complete and tested
/// ahead of that UI — see [ConceptTier]'s class doc.
class HighLowPrompt {
  /// Real sounding MIDI pitch played on the left ([firstInstrument]).
  final int firstMidi;

  /// Real sounding MIDI pitch played on the right ([secondInstrument]).
  final int secondMidi;

  /// Instrument the left side ([firstMidi]) sounds on.
  final HighLowInstrument firstInstrument;

  /// Instrument the right side ([secondMidi]) sounds on. Equal to
  /// [firstInstrument] for a same-instrument tier, a different (but
  /// pairable) instrument for a cross-instrument one — see the class doc.
  final HighLowInstrument secondInstrument;

  final int promptNumber;
  final PitchDirection targetDirection;

  /// Third note's real sounding MIDI pitch, for a three-note tier's
  /// prompt only — null for every two-note tier. See [isThreeNote].
  final int? thirdMidi;

  /// Instrument [thirdMidi] sounds on — null exactly when [thirdMidi] is.
  final HighLowInstrument? thirdInstrument;

  const HighLowPrompt({
    required this.firstMidi,
    required this.secondMidi,
    required this.firstInstrument,
    required this.secondInstrument,
    required this.promptNumber,
    required this.targetDirection,
    this.thirdMidi,
    this.thirdInstrument,
  }) : assert(
         (thirdMidi == null) == (thirdInstrument == null),
         'thirdMidi and thirdInstrument must both be set or both be null '
         '— got thirdMidi: $thirdMidi, thirdInstrument: $thirdInstrument.',
       );

  /// Whether this is a three-note (`ConceptTier.noteCount` 3) prompt.
  bool get isThreeNote => thirdMidi != null;

  /// Whether the second note (right instrument) is the higher of the two,
  /// by real sounding pitch. Two-note prompts only — see [highestIndex]
  /// for the three-note equivalent.
  PitchDirection get correctAnswer =>
      secondMidi > firstMidi ? PitchDirection.higher : PitchDirection.lower;

  /// Semitone distance between the first and second notes. Two-note
  /// prompts only: for a three-note prompt, [firstMidi]/[secondMidi]/
  /// [thirdMidi] are assigned to positions at random (Trello — a fixed
  /// position could otherwise become a giveaway), so first-to-second is
  /// not necessarily the smallest or even an adjacent gap in pitch order;
  /// see [sortedMidis] for the actual pairwise gaps a three-note prompt's
  /// generation enforced.
  int get difficulty => (secondMidi - firstMidi).abs();

  /// True when the left (first-played) instrument is the higher one.
  /// Two-note prompts only.
  bool get leftIsHigher => firstMidi > secondMidi;

  /// 0 (left) or 1 (right) — whichever side is actually higher. Two-note
  /// prompts only.
  int get higherSide => leftIsHigher ? 0 : 1;

  /// 0 (left) or 1 (right) — the side that answers [targetDirection] for
  /// this round (e.g. the low side, if this round is asking "which one is
  /// low?"). Two-note prompts only.
  int get targetSide =>
      targetDirection == PitchDirection.higher ? higherSide : 1 - higherSide;

  /// Check if the user's answer is correct (used by stages that ask
  /// "higher or lower", independent of [targetDirection]). Two-note
  /// prompts only.
  bool isCorrect(PitchDirection answer) => answer == correctAnswer;

  /// [firstMidi]/[secondMidi]/[thirdMidi] (three-note prompts only, the
  /// latter required non-null), ascending — the actual pitch order a
  /// three-note prompt's generation enforced adjacent-gap bounds on.
  List<int> get sortedMidis {
    assert(isThreeNote, 'sortedMidis is only meaningful for a 3-note prompt');
    return [firstMidi, secondMidi, thirdMidi!]..sort();
  }

  /// 0 (first), 1 (second), or 2 (third) — whichever position holds the
  /// highest of the three notes, i.e. the answer to a three-note round's
  /// only question, "which one is the highest" (see [ConceptTier]'s class
  /// doc for why three-note tiers never ask for the lowest). Three-note
  /// prompts only.
  int get highestIndex {
    assert(isThreeNote, 'highestIndex is only meaningful for a 3-note prompt');
    final midis = [firstMidi, secondMidi, thirdMidi!];
    var best = 0;
    for (var i = 1; i < midis.length; i++) {
      if (midis[i] > midis[best]) best = i;
    }
    return best;
  }
}

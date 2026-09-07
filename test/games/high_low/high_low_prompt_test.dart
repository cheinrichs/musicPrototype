import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/high_low_prompt.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

void main() {
  group('HighLowPrompt', () {
    test('allows two different instruments — a same-instrument round is a '
        'ConceptTier choice (instrumentsVary: false), not a hard rule '
        'this model enforces any more (Trello card "Rebuild the tier '
        'ladder as eight tiers (2x2x2)")', () {
      final prompt = HighLowPrompt(
        firstMidi: 60,
        secondMidi: 62,
        firstInstrument: HighLowInstrument.piano,
        secondInstrument: HighLowInstrument.violin,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );
      expect(prompt.firstInstrument, HighLowInstrument.piano);
      expect(prompt.secondInstrument, HighLowInstrument.violin);
    });

    test('constructor asserts thirdMidi and thirdInstrument are both set '
        'or both null', () {
      expect(
        () => HighLowPrompt(
          firstMidi: 60,
          secondMidi: 62,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 65,
          thirdInstrument: null,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('correctAnswer compares real sounding pitch directly — no '
        'per-instrument offset any more', () {
      final tubaPrompt = HighLowPrompt(
        firstMidi: 36, // real C2
        secondMidi: 43, // real G2
        firstInstrument: HighLowInstrument.tuba,
        secondInstrument: HighLowInstrument.tuba,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );
      final pianoPrompt = HighLowPrompt(
        firstMidi: 60, // real C4
        secondMidi: 67, // real G4
        firstInstrument: HighLowInstrument.piano,
        secondInstrument: HighLowInstrument.piano,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );

      expect(tubaPrompt.correctAnswer, PitchDirection.higher);
      expect(tubaPrompt.correctAnswer, pianoPrompt.correctAnswer);
    });

    test('difficulty is the raw semitone distance between the two real '
        'pitches', () {
      final prompt = HighLowPrompt(
        firstMidi: 60,
        secondMidi: 67,
        firstInstrument: HighLowInstrument.piano,
        secondInstrument: HighLowInstrument.piano,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );
      expect(prompt.difficulty, 7);
    });

    group('three-note prompts', () {
      test('isThreeNote is false with no third note, true with one', () {
        final twoNote = HighLowPrompt(
          firstMidi: 60,
          secondMidi: 67,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
        );
        expect(twoNote.isThreeNote, isFalse);

        final threeNote = HighLowPrompt(
          firstMidi: 60,
          secondMidi: 67,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 74,
          thirdInstrument: HighLowInstrument.piano,
        );
        expect(threeNote.isThreeNote, isTrue);
      });

      test('highestIndex finds the highest note regardless of which '
          'position it landed in — the whole point of shuffling positions '
          'is that a fixed slot can\'t be a giveaway', () {
        final firstIsHighest = HighLowPrompt(
          firstMidi: 74,
          secondMidi: 60,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 67,
          thirdInstrument: HighLowInstrument.piano,
        );
        expect(firstIsHighest.highestIndex, 0);

        final secondIsHighest = HighLowPrompt(
          firstMidi: 60,
          secondMidi: 74,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 67,
          thirdInstrument: HighLowInstrument.piano,
        );
        expect(secondIsHighest.highestIndex, 1);

        final thirdIsHighest = HighLowPrompt(
          firstMidi: 60,
          secondMidi: 67,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 74,
          thirdInstrument: HighLowInstrument.piano,
        );
        expect(thirdIsHighest.highestIndex, 2);
      });

      test('sortedMidis is the three real pitches in ascending order', () {
        final prompt = HighLowPrompt(
          firstMidi: 67,
          secondMidi: 60,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.piano,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
          thirdMidi: 74,
          thirdInstrument: HighLowInstrument.piano,
        );
        expect(prompt.sortedMidis, [60, 67, 74]);
      });
    });
  });
}

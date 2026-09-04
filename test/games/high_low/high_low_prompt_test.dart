import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/high_low_prompt.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

void main() {
  group('HighLowPrompt', () {
    test('constructor asserts both sides share an instrument', () {
      expect(
        () => HighLowPrompt(
          firstMidi: 60,
          secondMidi: 62,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.violin,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/high_low_prompt.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

void main() {
  group('HighLowPrompt', () {
    test('constructor asserts both sides share an instrument', () {
      expect(
        () => HighLowPrompt(
          firstNote: Note.c4,
          secondNote: Note.d4,
          firstInstrument: HighLowInstrument.piano,
          secondInstrument: HighLowInstrument.violin,
          promptNumber: 1,
          targetDirection: PitchDirection.higher,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('correctAnswer compares real sounding pitch, not logical slot', () {
      // Tuba's real pitch is two octaves below its logical slot (see
      // HighLowInstrument.realPitchOffsetSemitones). With both sides on
      // tuba the offset cancels, so this must still land on the note
      // that's really higher, exactly as a piano pair would.
      final tubaPrompt = HighLowPrompt(
        firstNote: Note.c4,
        secondNote: Note.g4,
        firstInstrument: HighLowInstrument.tuba,
        secondInstrument: HighLowInstrument.tuba,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );
      final pianoPrompt = HighLowPrompt(
        firstNote: Note.c4,
        secondNote: Note.g4,
        firstInstrument: HighLowInstrument.piano,
        secondInstrument: HighLowInstrument.piano,
        promptNumber: 1,
        targetDirection: PitchDirection.higher,
      );

      expect(tubaPrompt.correctAnswer, PitchDirection.higher);
      expect(tubaPrompt.correctAnswer, pianoPrompt.correctAnswer);
    });
  });
}

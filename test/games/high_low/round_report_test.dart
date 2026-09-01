import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/build_info.dart';
import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/round_report.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/models/round_order.dart';

void main() {
  const build = BuildInfo(
    appVersion: '1.0.0',
    buildNumber: '42',
    commitSha: 'abc1234',
  );

  RoundReport buildReport({
    required HighLowInstrument leftInstrument,
    required Note leftNote,
    required HighLowInstrument rightInstrument,
    required Note rightNote,
    AgencyStage agencyStage = AgencyStage.trigger,
  }) {
    return RoundReport(
      capturedAt: DateTime.utc(2026, 9, 1, 12, 0, 0),
      build: build,
      conceptTier: ConceptTier.t3,
      agencyStage: agencyStage,
      roundOrder: RoundOrder.blocked,
      roundNumber: 3,
      totalRounds: 5,
      targetDirection: PitchDirection.higher,
      left: RoundReportSide(instrument: leftInstrument, note: leftNote),
      right: RoundReportSide(instrument: rightInstrument, note: rightNote),
      response: const RoundReportResponse(
        applicable: true,
        side: 1,
        markedCorrect: true,
      ),
    );
  }

  test('logical and real-pitch agree when neither side is transposed', () {
    final report = buildReport(
      leftInstrument: HighLowInstrument.piano,
      leftNote: Note.c4,
      rightInstrument: HighLowInstrument.violin,
      rightNote: Note.g4,
    );

    expect(report.higherSideLogical, 1); // right (G4) > left (C4)
    expect(report.higherSideRealPitch, 1);
    expect(report.logicalAndRealPitchAgree, isTrue);
  });

  test(
    'logical and real-pitch DISAGREE when pairing a transposed instrument '
    '(tuba, real pitch 2 octaves below its label) against a non-transposed '
    'one — this is the exact mismatch Report This Round exists to surface',
    () {
      // Logical slots: tuba G4 (midi 67) is logically higher than piano C4
      // (midi 60). But tuba's *real* sounding pitch is G2 (67-24=43),
      // which is well below piano's real C4 (60) — so a listener hears
      // the opposite of what HighLowPrompt.correctAnswer would score.
      final report = buildReport(
        leftInstrument: HighLowInstrument.piano,
        leftNote: Note.c4,
        rightInstrument: HighLowInstrument.tuba,
        rightNote: Note.g4,
      );

      expect(report.higherSideLogical, 1); // right (tuba G4) logically higher
      expect(report.higherSideRealPitch, 0); // but left (piano) really higher
      expect(report.logicalAndRealPitchAgree, isFalse);
    },
  );

  test('RoundReportSide computes real pitch via instrument transposition', () {
    final tubaSide = RoundReportSide(
      instrument: HighLowInstrument.tuba,
      note: Note.c4,
    );
    expect(tubaSide.realMidiNumber, Note.c4.midiNumber - 24);
    expect(tubaSide.realNoteName, 'C2');
    expect(tubaSide.realFrequencyHz, closeTo(65.41, 0.1));

    final pianoSide = RoundReportSide(
      instrument: HighLowInstrument.piano,
      note: Note.c4,
    );
    expect(pianoSide.realMidiNumber, Note.c4.midiNumber);
    expect(pianoSide.realNoteName, 'C4');
    expect(pianoSide.realFrequencyHz, closeTo(261.63, 0.1));
  });

  test('toJson round-trips every field the audit/report needs', () {
    final report = buildReport(
      leftInstrument: HighLowInstrument.tuba,
      leftNote: Note.g4,
      rightInstrument: HighLowInstrument.piano,
      rightNote: Note.c4,
    );
    final json = report.toJson();

    expect(json['build'], build.toJson());
    expect(json['session']['conceptTier'], 't3');
    expect(json['session']['agencyStage'], 'trigger');
    expect(json['session']['ageBand'], kCurrentAgeBand);
    expect(json['round']['roundNumber'], 3);
    expect(json['round']['left']['instrument'], 'tuba');
    expect(json['round']['left']['assetPath'], 'assets/audio/notes/tuba/g4.mp3');
    expect(json['round']['left']['realNoteName'], 'G2');
    expect(json['round']['higherSideLogical'], 'left');
    expect(json['round']['higherSideRealPitch'], 'right');
    expect(json['round']['logicalAndRealPitchAgree'], false);
    expect(json['round']['response'], {
      'applicable': true,
      'side': 'right',
      'markedCorrect': true,
    });
  });

  test('response is not applicable outside Trigger', () {
    final report = RoundReport(
      capturedAt: DateTime.utc(2026, 9, 1),
      build: build,
      conceptTier: ConceptTier.t1,
      agencyStage: AgencyStage.observe,
      roundOrder: RoundOrder.mixed,
      roundNumber: 1,
      totalRounds: 5,
      targetDirection: PitchDirection.lower,
      left: const RoundReportSide(
        instrument: HighLowInstrument.piano,
        note: Note.c4,
      ),
      right: const RoundReportSide(
        instrument: HighLowInstrument.piano,
        note: Note.g4,
      ),
      response: const RoundReportResponse(
        applicable: false,
        side: null,
        markedCorrect: null,
      ),
    );

    expect(report.toJson()['round']['response'], {
      'applicable': false,
      'side': null,
      'markedCorrect': null,
    });
  });
}

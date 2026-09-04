import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/build_info.dart';
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
    required int leftMidi,
    required HighLowInstrument rightInstrument,
    required int rightMidi,
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
      left: RoundReportSide(instrument: leftInstrument, midi: leftMidi),
      right: RoundReportSide(instrument: rightInstrument, midi: rightMidi),
      response: const RoundReportResponse(
        applicable: true,
        side: 1,
        markedCorrect: true,
      ),
    );
  }

  test('higherSide reflects real sounding pitch directly — no separate '
      'logical-vs-real duality any more', () {
    final report = buildReport(
      leftInstrument: HighLowInstrument.piano,
      leftMidi: 60, // C4
      rightInstrument: HighLowInstrument.violin,
      rightMidi: 67, // G4
    );

    expect(report.higherSide, 1); // right (G4) > left (C4)
  });

  test('RoundReportSide resolves the asset path directly by real MIDI '
      'pitch — no per-instrument offset to apply any more', () {
    final tubaSide = RoundReportSide(
      instrument: HighLowInstrument.tuba,
      midi: 36, // real C2, tuba's lowest sample
    );
    expect(tubaSide.assetPath, 'assets/audio/notes/tuba/c2.mp3');
    expect(tubaSide.noteName, 'C2');
    expect(tubaSide.frequencyHz, closeTo(65.41, 0.1));

    final pianoSide = RoundReportSide(
      instrument: HighLowInstrument.piano,
      midi: 60, // C4
    );
    expect(pianoSide.assetPath, 'assets/audio/notes/piano/c4.mp3');
    expect(pianoSide.noteName, 'C4');
    expect(pianoSide.frequencyHz, closeTo(261.63, 0.1));
  });

  test('toJson round-trips every field the audit/report needs', () {
    final report = buildReport(
      leftInstrument: HighLowInstrument.tuba,
      leftMidi: 43, // real G2
      rightInstrument: HighLowInstrument.piano,
      rightMidi: 60, // real C4
    );
    final json = report.toJson();

    expect(json['build'], build.toJson());
    expect(json['session']['conceptTier'], 't3');
    expect(json['session']['agencyStage'], 'trigger');
    expect(json['session']['ageBand'], kCurrentAgeBand);
    expect(json['round']['roundNumber'], 3);
    expect(json['round']['left']['instrument'], 'tuba');
    expect(
      json['round']['left']['assetPath'],
      'assets/audio/notes/tuba/g2.mp3',
    );
    expect(json['round']['left']['noteName'], 'G2');
    expect(
      json['round']['higherSide'],
      'right',
    ); // piano C4 (60) > tuba G2 (43)
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
        midi: 60,
      ),
      right: const RoundReportSide(
        instrument: HighLowInstrument.piano,
        midi: 67,
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

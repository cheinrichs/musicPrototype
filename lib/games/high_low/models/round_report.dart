import 'dart:math' as math;

import '../../../app/build_info.dart';
import '../../../models/agency_stage.dart';
import '../../../models/concept_tier.dart';
import '../../../models/pitch_direction.dart';
import '../../../models/round_order.dart';
import 'high_low_instrument.dart';
import 'high_low_prompt.dart';

/// The age band this build currently targets. Not yet a real, selectable
/// field anywhere in the app — [AgencyStage]'s doc comment notes the A0-A2
/// ladder implemented so far is "for the 2-3 age band" specifically; final
/// age-band boundaries are explicitly still undecided (see
/// docs/product/LEARNING_ARCHITECTURE.md's "still open" list). Recorded
/// here as a constant, not invented UI, until that's settled.
const String kCurrentAgeBand = '2-3';

const int _reportSchemaVersion = 1;

/// A note as played on one side of the round: which instrument, and the
/// real sounding MIDI pitch its sample plays at — there's no separate
/// "logical" number any more (see [HighLowInstrument]'s class doc for why
/// that duality existed once and was retired: it let a wrong transposition
/// hide in plain sight for a year because nothing compared the two).
class RoundReportSide {
  final HighLowInstrument instrument;
  final int midi;

  const RoundReportSide({required this.instrument, required this.midi});

  String get assetPath => instrument.assetPathForMidi(midi);

  double get frequencyHz => 440.0 * math.pow(2, (midi - 69) / 12.0);

  String get noteName => _midiToNoteName(midi);

  Map<String, dynamic> toJson() => {
    'instrument': instrument.name,
    'assetPath': assetPath,
    'midi': midi,
    'noteName': noteName,
    'frequencyHz': double.parse(frequencyHz.toStringAsFixed(2)),
  };
}

/// The child's response to the round, if any yet. Only Trigger (A2)
/// scores a response at all — Observe/Participate never do (see
/// [HighLowGameState]'s class doc) — so [applicable] is false whenever
/// [agencyStage] isn't [AgencyStage.trigger], and [side]/[markedCorrect]
/// are both null when Trigger hasn't seen a drop yet this round.
class RoundReportResponse {
  final bool applicable;
  final int? side;
  final bool? markedCorrect;

  const RoundReportResponse({
    required this.applicable,
    required this.side,
    required this.markedCorrect,
  });

  Map<String, dynamic> toJson() => {
    'applicable': applicable,
    'side': side == null ? null : (side == 0 ? 'left' : 'right'),
    'markedCorrect': markedCorrect,
  };
}

/// A full, replayable snapshot of one High/Low round, captured on demand
/// via the "Report this round" button (Trello card on0EymSu) so Cooper can
/// send back exact reproduction state instead of describing a round from
/// memory. Local-only — see [RoundReportService] for the JSON+screenshot
/// write-and-share flow; nothing here ever leaves the device except
/// through the share sheet the child's grown-up explicitly drives.
///
/// Reproducibility: [left]/[right]/[targetDirection]/[conceptTier]/
/// [agencyStage]/[roundOrder] together are exactly [PromptGenerator] and
/// [HighLowGameState]'s own inputs for this round — enough for a future
/// loader to reconstruct and replay it deterministically (by feeding a
/// fixed [HighLowPrompt] straight to [HighLowGameState] instead of letting
/// [PromptGenerator] roll a random one). No loader exists yet; this is
/// just what it would need.
class RoundReport {
  final DateTime capturedAt;
  final BuildInfo build;
  final ConceptTier conceptTier;
  final AgencyStage agencyStage;
  final RoundOrder roundOrder;
  final String ageBand;

  final int roundNumber;
  final int totalRounds;
  final PitchDirection targetDirection;
  final RoundReportSide left;
  final RoundReportSide right;
  final RoundReportResponse response;

  const RoundReport({
    required this.capturedAt,
    required this.build,
    required this.conceptTier,
    required this.agencyStage,
    required this.roundOrder,
    required this.roundNumber,
    required this.totalRounds,
    required this.targetDirection,
    required this.left,
    required this.right,
    required this.response,
    this.ageBand = kCurrentAgeBand,
  });

  /// Which side is the higher real sounding pitch — what
  /// [HighLowPrompt.correctAnswer] scores against.
  int get higherSide => right.midi > left.midi ? 1 : 0;

  Map<String, dynamic> toJson() => {
    'reportSchemaVersion': _reportSchemaVersion,
    'capturedAt': capturedAt.toIso8601String(),
    'build': build.toJson(),
    'session': {
      'conceptTier': conceptTier.name,
      'agencyStage': agencyStage.name,
      'roundOrder': roundOrder.name,
      'ageBand': ageBand,
    },
    'round': {
      'roundNumber': roundNumber,
      'totalRounds': totalRounds,
      'targetDirection': targetDirection.name,
      'left': left.toJson(),
      'right': right.toJson(),
      'higherSide': higherSide == 0 ? 'left' : 'right',
      'response': response.toJson(),
    },
  };
}

String _midiToNoteName(int midi) {
  const names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final name = names[midi % 12];
  final octave = (midi ~/ 12) - 1;
  return '$name$octave';
}

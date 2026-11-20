import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/audio/strike_figure.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/high_low_prompt.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/game_status.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

/// Short sounds are presented three times in a round's introduction, a
/// child's own tap once (Cooper, 2026-11-20). Decided by measured length,
/// never by instrument name.
void main() {
  group('the short-sound rule', () {
    test('400 ms is the line: under it three strikes, else one', () {
      expect(StrikeFigure.shortBelow, const Duration(milliseconds: 400));
      expect(StrikeFigure.strikesFor(const Duration(milliseconds: 399)), 3);
      expect(StrikeFigure.strikesFor(const Duration(milliseconds: 400)), 1);
      expect(StrikeFigure.strikesFor(null), 1);
    });

    test('three strikes, 250-300 ms apart, all started inside a second', () {
      expect(StrikeFigure.shortStrikes, 3);
      expect(StrikeFigure.spacing.inMilliseconds, inInclusiveRange(250, 300));
      expect(
        StrikeFigure.startOf(StrikeFigure.shortStrikes - 1),
        lessThan(const Duration(seconds: 1)),
      );
    });

    test('the xylophone is short; the flute and every other real '
        'instrument are not', () {
      expect(HighLowInstrument.xylophone.introStrikes, 3);
      expect(HighLowInstrument.flute.introStrikes, 1);
      for (final i in HighLowInstrument.values) {
        expect(
          HighLowInstrument.measuredDecay[i],
          isNotNull,
          reason: '${i.name} has no measured length',
        );
        if (i != HighLowInstrument.xylophone) {
          expect(i.introStrikes, 1, reason: i.name);
        }
      }
    });
  });

  group('High vs Low intro', () {
    for (final stage in AgencyStage.values) {
      testWidgets('${stage.name}: a short instrument plays three times a '
          'side in the intro', (tester) async {
        final audio = _EventAudio();
        final state = HighLowGameState(
          totalPrompts: 2,
          agencyStage: stage,
          audio: audio,
          generator: _OneInstrument(HighLowInstrument.xylophone),
        );
        state.startGame();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 1000));
        }
        final notes = audio.events.where((e) => e.startsWith('note:'));
        expect(notes, hasLength(6));
        expect(notes.take(3).toSet(), hasLength(1), reason: 'one note x3');
        expect(notes.skip(3).toSet(), hasLength(1), reason: 'one note x3');
        state.dispose();
      });
    }

    testWidgets('a long instrument plays once a side', (tester) async {
      final audio = _EventAudio();
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.decide,
        audio: audio,
        generator: _OneInstrument(HighLowInstrument.flute),
      );
      state.startGame();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(audio.events.where((e) => e.startsWith('note:')), hasLength(2));
      state.dispose();
    });

    testWidgets('the strikes are a beat apart, not stacked', (tester) async {
      final audio = _EventAudio();
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.observe,
        audio: audio,
        generator: _OneInstrument(HighLowInstrument.xylophone),
      );
      state.startGame();
      await tester.pump();
      int notes() => audio.events.where((e) => e.startsWith('note:')).length;
      expect(notes(), 1);
      await tester.pump(StrikeFigure.spacing);
      expect(notes(), 2);
      await tester.pump(StrikeFigure.spacing);
      expect(notes(), 3);
      state.dispose();
    });

    testWidgets('Observe: each line comes after its three strikes, never '
        'between them (voice rule 4)', (tester) async {
      final audio = _EventAudio();
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.observe,
        audio: audio,
        generator: _OneInstrument(HighLowInstrument.xylophone),
      );
      state.startGame();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
      }
      final kinds = audio.events.map((e) => e.split(':').first).toList();
      expect(kinds.take(8), [
        'note',
        'note',
        'note',
        'line',
        'note',
        'note',
        'note',
        'line',
      ]);
      state.dispose();
    });

    testWidgets("a child's own tap plays the note once", (tester) async {
      final audio = _EventAudio();
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.decide,
        audio: audio,
        generator: _OneInstrument(HighLowInstrument.xylophone),
      );
      state.startGame();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(state.status, GameStatus.awaitingInput);
      audio.events.clear();
      state.tapInstrument(0);
      await tester.pump(const Duration(seconds: 2));
      expect(audio.events.where((e) => e.startsWith('note:')), hasLength(1));
      state.dispose();
    });
  });
}

/// Every round puts [instrument] on both sides, a fifth apart.
class _OneInstrument extends PromptGenerator {
  final HighLowInstrument instrument;
  _OneInstrument(this.instrument) : super(random: Random(1));

  @override
  HighLowPrompt generatePrompt({
    required int promptNumber,
    required ConceptTier tier,
    required PitchDirection targetDirection,
  }) {
    final midis = instrument.availableMidis;
    final low = midis[midis.length ~/ 2 - 4];
    return HighLowPrompt(
      firstMidi: low,
      secondMidi: low + 7,
      firstInstrument: instrument,
      secondInstrument: instrument,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

class _EventAudio implements AudioController {
  final List<String> events = [];

  @override
  Future<void> playVoiceLine(SpokenLine line) async {
    events.add('line:${line.assetName}');
  }

  @override
  Future<void> playVoiceLineAndAwait(SpokenLine line) async {
    events.add('line:${line.assetName}');
  }

  @override
  Future<void> playAssetForScale(String path, {double volume = 1.0}) async {
    events.add('note:$path');
  }

  @override
  Future<void> playSfx(SfxType sfx) async {}

  @override
  void stopCurrentNote() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

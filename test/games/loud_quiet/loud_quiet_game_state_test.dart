import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:ear_trainer/games/loud_quiet/state/loud_quiet_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/game_status.dart';
import 'package:ear_trainer/models/round_order.dart';
import 'package:ear_trainer/models/round_set_length.dart';

/// Records every sound asked for — the path and its gain — and plays nothing.
class _RecordingAudio implements AudioController {
  final List<(String, double)> notes = [];
  final List<String> lines = [];

  /// What every sample measures here — longer than a celebration, so a
  /// test can tell the round waiting for the sound from the timer.
  static const length = Duration(milliseconds: 1700);

  @override
  Future<Duration?> noteLength(String path) async => length;

  @override
  Future<void> playAssetForScale(String path, {double volume = 1.0}) async {
    notes.add((path, volume));
  }

  @override
  Future<void> playVoiceLine(SpokenLine line) async {
    lines.add(line.assetName);
  }

  @override
  Future<void> playVoiceLineAndAwait(SpokenLine line) async {
    lines.add(line.assetName);
  }

  @override
  Future<void> playSfx(SfxType sfx) async {}

  @override
  void stopCurrentNote() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

LoudQuietGameState _game(
  _RecordingAudio audio, {
  AgencyStage stage = AgencyStage.observe,
  ConceptTier tier = ConceptTier.t1,
  int seed = 1,
}) => LoudQuietGameState(
  audio: audio,
  random: math.Random(seed),
  agencyStage: stage,
  conceptTier: tier,
);

/// Lets the round's two opening sounds finish.
Future<void> _playThrough(WidgetTester tester) => tester.pump(
  LoudQuietGameState.noteGap * 2 + const Duration(milliseconds: 10),
);

void main() {
  group('LoudQuietRound', () {
    test('both sides play the same note; only the gain differs', () {
      final random = math.Random(3);
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 40; i++) {
          final r = LoudQuietRound.generate(
            tier: tier,
            asksLoud: i.isEven,
            random: random,
          );
          expect(r.leftInstrument.availableMidis, contains(r.midi));
          expect(r.rightInstrument.availableMidis, contains(r.midi));
          expect(r.gainOf(r.loudSide), 1.0);
          expect(
            r.gainOf(1 - r.loudSide),
            tier.isWide
                ? LoudQuietRound.wideQuietGain
                : LoudQuietRound.narrowQuietGain,
          );
          if (!tier.instrumentsVary) {
            expect(r.leftInstrument, r.rightInstrument);
          }
        }
      }
    });

    test('the perceptual trim (card 207) cuts oboe most, flute and guitar '
        'a little, and nothing else; the needle ignores it', () {
      LoudQuietRound round(HighLowInstrument i) => LoudQuietRound(
        leftInstrument: i,
        rightInstrument: i,
        midi: 72,
        loudSide: 0,
        quietGain: LoudQuietRound.wideQuietGain,
        asksLoud: true,
      );
      double trimDb(HighLowInstrument i) =>
          20 * math.log(round(i).playbackGainOf(0)) / math.ln10;
      expect(trimDb(HighLowInstrument.oboe), closeTo(-3.0, 1e-9));
      expect(trimDb(HighLowInstrument.flute), closeTo(-1.5, 1e-9));
      expect(trimDb(HighLowInstrument.guitar), closeTo(-1.0, 1e-9));
      for (final i in [
        HighLowInstrument.cello,
        HighLowInstrument.piano,
        HighLowInstrument.trumpet,
        HighLowInstrument.violin,
        HighLowInstrument.bells,
      ]) {
        expect(round(i).playbackGainOf(0), 1.0, reason: i.name);
      }
      expect(
        trimDb(HighLowInstrument.oboe),
        lessThan(trimDb(HighLowInstrument.flute)),
        reason: 'oboe cut hardest',
      );
      // The quiet end must survive: no trim pushes a quiet sound more than
      // a few dB below the untrimmed quiet level.
      for (final db in LoudQuietRound.perceptualTrimDb.values) {
        expect(db, inInclusiveRange(-4.0, 0.0));
      }
    });

    test('the tuba is never drawn: too little of it reaches a phone '
        'speaker to survive the quiet end', () {
      final random = math.Random(9);
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 60; i++) {
          final r = LoudQuietRound.generate(
            tier: tier,
            asksLoud: true,
            random: random,
          );
          expect(r.leftInstrument, isNot(HighLowInstrument.tuba));
          expect(r.rightInstrument, isNot(HighLowInstrument.tuba));
        }
      }
    });

    test('the loud side lands on both sides over a session', () {
      final random = math.Random(5);
      final sides = {
        for (var i = 0; i < 30; i++)
          LoudQuietRound.generate(
            tier: ConceptTier.t1,
            asksLoud: true,
            random: random,
          ).loudSide,
      };
      expect(sides, {0, 1});
    });

    test('target is the loud side when asking loud, the other when quiet', () {
      final loud = LoudQuietRound.generate(
        tier: ConceptTier.t1,
        asksLoud: true,
        random: math.Random(1),
      );
      expect(loud.targetSide, loud.loudSide);
      final quiet = LoudQuietRound.generate(
        tier: ConceptTier.t1,
        asksLoud: false,
        random: math.Random(1),
      );
      expect(quiet.targetSide, 1 - quiet.loudSide);
    });

    test('the dial reads up from zero below the quietest (card 208): the '
        'quiet sound a short way, a narrow round\'s quiet one past halfway, '
        'full gain all the way', () {
      expect(
        LoudQuietRound.needlePosition(LoudQuietRound.wideQuietGain),
        closeTo(2 / 14, 0.01),
      );
      expect(
        LoudQuietRound.needlePosition(LoudQuietRound.narrowQuietGain),
        closeTo(8 / 14, 0.01),
      );
      expect(LoudQuietRound.needlePosition(1.0), closeTo(1, 1e-9));
      expect(
        LoudQuietRound.needlePosition(0.01),
        0,
        reason: 'never below rest',
      );
    });
  });

  group('LoudQuietGameState', () {
    testWidgets('a round opens by playing both sides at their trimmed '
        'gains', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio)..startGame();
      final round = game.currentRound!;
      await _playThrough(tester);
      expect(audio.notes.map((n) => n.$2).toList(), [
        round.playbackGainOf(0),
        round.playbackGainOf(1),
      ]);
      expect(game.status, GameStatus.awaitingInput);
      game.dispose();
    });

    // Card 208: every sound the dial is free to show sends the needle a
    // complete gesture; the screen plays it out (see dial_needle_test).
    for (final stage in [AgencyStage.observe, AgencyStage.explore]) {
      testWidgets('${stage.name}: each prompt sound sends a swing to its '
          'level, timed to the sample\'s real length', (tester) async {
        final audio = _RecordingAudio();
        final game = _game(audio, stage: stage)..startGame();
        final round = game.currentRound!;
        await tester.pump();
        final first = game.needleSwing!;
        expect(first.position, LoudQuietRound.needlePosition(round.gainOf(0)));
        expect(first.length, _RecordingAudio.length);
        await tester.pump(LoudQuietGameState.noteGap);
        final second = game.needleSwing!;
        expect(second.serial, greaterThan(first.serial));
        expect(second.position, LoudQuietRound.needlePosition(round.gainOf(1)));
        expect(game.dialLocked, isFalse);
        await _playThrough(tester);
        game.dispose();
      });
    }

    testWidgets('the same instrument tapped four times swings four times — '
        'the bug Cooper found', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.explore)..startGame();
      await _playThrough(tester);
      final loud = game.currentRound!.loudSide;
      final serials = <int>{};
      for (var i = 0; i < 4; i++) {
        game.tapInstrument(loud);
        await tester.pump();
        serials.add(game.needleSwing!.serial);
        expect(game.needleSwing!.position, 1.0);
      }
      expect(serials, hasLength(4));
      await tester.pump(const Duration(seconds: 2));
      game.dispose();
    });

    testWidgets('Decide: the dial is locked — the prompt and taps never move '
        'it, a wrong drop leaves it shut — and the correct drop opens it: '
        'the instrument plays, the needle sweeps, and the round waits for '
        'the sound', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      expect(game.dialLocked, isTrue);
      expect(game.needleSwing, isNull, reason: 'prompt never moved it');
      final round = game.currentRound!;
      game.tapInstrument(round.loudSide);
      await tester.pump();
      expect(game.needleSwing, isNull, reason: 'taps never move it');

      game.dropInstrument(1 - round.targetSide);
      await tester.pump();
      expect(game.dialLocked, isTrue, reason: 'a wrong drop leaves it shut');
      await tester.pump(LoudQuietGameState.retryMinimum);

      audio.notes.clear();
      game.dropInstrument(round.targetSide);
      expect(game.dialLocked, isFalse);
      await tester.pump(LoudQuietGameState.dialOpenBeat);
      await tester.pump();
      expect(
        audio.notes.single.$1,
        contains(round.instrumentOf(round.targetSide).name),
      );
      expect(
        game.needleSwing!.position,
        LoudQuietRound.needlePosition(round.gainOf(round.targetSide)),
      );
      expect(game.currentPromptIndex, 0);
      await tester.pump(LoudQuietGameState.celebration);
      expect(game.currentPromptIndex, 0, reason: 'the sound is still playing');
      await tester.pump(_RecordingAudio.length);
      expect(game.currentPromptIndex, 1);
      expect(game.dialLocked, isTrue, reason: 'locked again for the next');
      await tester.pump(const Duration(seconds: 6));
      game.dispose();
    });

    testWidgets('tapping the character who is not asking giggles, then the '
        'sounds; the asking one goes straight to the sounds (card 195)', (
      tester,
    ) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.explore)..startGame();
      await _playThrough(tester);
      final askerIsPiper = !game.asksLoud;
      audio.notes.clear();
      game.tapCharacter(piper: !askerIsPiper);
      await tester.pump();
      expect(audio.lines.single, askerIsPiper ? 'giggleClef' : 'gigglePiper');
      await _playThrough(tester);
      expect(audio.notes, hasLength(2));
      audio.lines.clear();
      audio.notes.clear();
      game.tapCharacter(piper: askerIsPiper);
      await _playThrough(tester);
      expect(audio.lines, isEmpty);
      expect(audio.notes, hasLength(2));
      game.dispose();
    });

    testWidgets('a replay during a wrong drop\'s "not that one" does not '
        'strand it on screen', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      game.dropInstrument(1 - game.currentRound!.targetSide);
      expect(game.drop, LoudQuietDrop.retry);
      game.tapCharacter(piper: true);
      await tester.pump(LoudQuietGameState.retryMinimum);
      expect(game.drop, LoudQuietDrop.none);
      await _playThrough(tester);
      game.dispose();
    });

    testWidgets('a tap plays at that side\'s gain', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio)..startGame();
      await _playThrough(tester);
      audio.notes.clear();
      final round = game.currentRound!;
      game.tapInstrument(1 - round.loudSide);
      expect(audio.notes.single.$2, round.playbackGainOf(1 - round.loudSide));
      game.dispose();
    });

    testWidgets('Observe: the arrow comes once both are heard; tapping it '
        'logs the round and moves on', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio)..startGame();
      await _playThrough(tester);
      game.tapInstrument(0);
      expect(game.showArrow, isFalse);
      game.tapInstrument(0);
      expect(game.showArrow, isFalse);
      game.tapInstrument(1);
      expect(game.showArrow, isTrue);
      game.tapArrow();
      expect(game.currentPromptIndex, 1);
      expect(game.records.single.observeTapSequence, [0, 0, 1]);
      expect(game.records.single.firstResponseCorrect, isNull);
      expect(game.correctCount, 1);
      game.dispose();
    });

    testWidgets('Explore: five correct taps celebrate; wrong taps never '
        'fail the round', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.explore)..startGame();
      await _playThrough(tester);
      final target = game.currentRound!.targetSide;
      for (var i = 0; i < 7; i++) {
        game.tapInstrument(1 - target);
      }
      expect(game.status, GameStatus.awaitingInput);
      expect(game.sparkleSide, isNull);
      for (var i = 0; i < 4; i++) {
        game.tapInstrument(target);
      }
      expect(game.sparkleSide, target);
      expect(game.correctTapProgress, 4);
      final confetti = game.confettiTrigger;
      game.tapInstrument(target);
      expect(game.confettiTrigger, confetti + 1);
      expect(game.status, GameStatus.showingFeedback);
      expect(game.records.single.correctTapCount, 5);
      expect(game.records.single.wrongTapCount, 7);
      expect(game.records.single.firstResponseCorrect, isFalse);
      await tester.pump(LoudQuietGameState.celebration);
      expect(game.currentPromptIndex, 1);
      game.dispose();
    });

    testWidgets('Explore: five taps on the wrong one bring a nudge in the '
        'asking character\'s voice, with the thinking pose', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.explore)..startGame();
      await _playThrough(tester);
      final wrong = 1 - game.currentRound!.targetSide;
      for (var i = 0; i < 5; i++) {
        game.tapInstrument(wrong);
      }
      expect(audio.lines, hasLength(1));
      expect(game.isConsidering, isTrue);
      await tester.pump(LoudQuietGameState.retryMinimum);
      expect(game.isConsidering, isFalse);
      game.dispose();
    });

    testWidgets('Explore: guidance joins after six seconds', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.explore)..startGame();
      await _playThrough(tester);
      expect(game.guidanceText, isNull);
      await tester.pump(LoudQuietGameState.guidanceDelay);
      expect(game.guidanceText, isNotNull);
      expect(game.captionText, isNotNull);
      game.dispose();
    });

    testWidgets('Decide: a tap only plays — nothing is answered', (
      tester,
    ) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      final target = game.currentRound!.targetSide;
      for (var i = 0; i < 6; i++) {
        game.tapInstrument(target);
      }
      expect(game.status, GameStatus.awaitingInput);
      expect(game.records, isEmpty);
      game.dispose();
    });

    testWidgets('Decide: a wrong drop settles back with a nudge; the right '
        'one lands and scores', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      final target = game.currentRound!.targetSide;
      game.dropInstrument(1 - target);
      expect(game.drop, LoudQuietDrop.retry);
      expect(audio.lines, hasLength(1));
      await tester.pump(LoudQuietGameState.retryMinimum);
      expect(game.drop, LoudQuietDrop.none);
      game.dropInstrument(target);
      expect(game.drop, LoudQuietDrop.correct);
      expect(game.canDrop, isFalse);
      expect(game.correctCount, 1);
      expect(game.records.single.firstResponseCorrect, isFalse);
      // The lock opens and the instrument plays out before the next round.
      await tester.pump(LoudQuietGameState.dialOpenBeat);
      await tester.pump(_RecordingAudio.length);
      expect(game.currentPromptIndex, 1);
      expect(game.drop, LoudQuietDrop.none);
      game.dispose();
    });

    testWidgets('blocked order asks loud first, then quiet', (tester) async {
      final audio = _RecordingAudio();
      final game = LoudQuietGameState(
        audio: audio,
        random: math.Random(2),
        roundOrder: RoundOrder.blocked,
        totalPrompts: 5,
      )..startGame();
      final asks = <bool>[];
      for (var i = 0; i < game.totalPrompts; i++) {
        asks.add(game.asksLoud);
        game.escape();
      }
      expect(asks, [true, true, true, false, false]);
      game.dispose();
    });

    testWidgets('Skip logs the round as skipped, unscored, and a skip during '
        'the celebration is not logged twice', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      game.escape();
      expect(game.records.single.skipped, isTrue);
      expect(game.correctCount, 0);
      await _playThrough(tester);
      game.dropInstrument(game.currentRound!.targetSide);
      game.escape();
      expect(game.records, hasLength(2));
      expect(game.records.last.skipped, isFalse);
      game.dispose();
    });

    test('the set length comes from the shared per-agency setting (card '
        '196): 3 at Observe, 4 at Explore, 5 at Decide', () {
      final audio = _RecordingAudio();
      for (final (stage, n) in [
        (AgencyStage.observe, 3),
        (AgencyStage.explore, 4),
        (AgencyStage.decide, 5),
      ]) {
        final game = _game(audio, stage: stage);
        expect(game.totalPrompts, n, reason: stage.name);
        game.dispose();
      }
    });

    testWidgets('a changed setting is what the set runs, fixed when the set '
        'starts', (tester) async {
      final audio = _RecordingAudio();
      final game = LoudQuietGameState(
        audio: audio,
        random: math.Random(1),
        agencyStage: AgencyStage.explore,
        roundSetLength: RoundSetLength.standard.withLength(
          AgencyStage.explore,
          2,
        ),
      )..startGame();
      expect(game.totalPrompts, 2);
      game.agencyStage = AgencyStage.decide;
      expect(game.totalPrompts, 2, reason: 'fixed for this set');
      game.escape();
      game.escape();
      expect(game.status, GameStatus.completed);
      game.dispose();
    });

    testWidgets('the session completes after the last round', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio)..startGame();
      for (var i = 0; i < game.totalPrompts; i++) {
        game.escape();
      }
      expect(game.status, GameStatus.completed);
      expect(game.records, hasLength(game.totalPrompts));
      game.dispose();
    });
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:ear_trainer/models/dial_mode.dart';
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

    test('needle: full gain at the loud end, the quietest at the quiet end, '
        'a narrow round\'s quiet sound in the middle', () {
      expect(LoudQuietRound.needlePosition(1.0), closeTo(1, 1e-9));
      expect(
        LoudQuietRound.needlePosition(LoudQuietRound.wideQuietGain),
        closeTo(-1, 1e-9),
      );
      expect(
        LoudQuietRound.needlePosition(LoudQuietRound.narrowQuietGain),
        closeTo(0, 0.01),
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

    // Card 208: by default the needle follows the round's own playback at
    // every agency, Decide included, then settles back to rest.
    for (final stage in AgencyStage.values) {
      testWidgets('${stage.name}: the needle swings to each sound of the '
          'prompt, then settles back to rest', (tester) async {
        final audio = _RecordingAudio();
        final game = _game(audio, stage: stage)..startGame();
        final round = game.currentRound!;
        double at(int side) =>
            LoudQuietRound.needlePosition(round.gainOf(side));
        await tester.pump();
        expect(game.needle, closeTo(at(0), 1e-9));
        await tester.pump(LoudQuietGameState.noteGap);
        expect(game.needle, closeTo(at(1), 1e-9));
        await tester.pump(LoudQuietGameState.noteGap);
        expect(game.needle, 0, reason: 'not parked on the answer');
        expect(game.records, isEmpty);
        game.escape();
        expect(game.records.single.dialMode, 'everySound');
        game.dispose();
      });
    }

    testWidgets('the needle follows the child\'s tap; a replay swings it '
        'again and settles it back to rest', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio)..startGame();
      await _playThrough(tester);
      final round = game.currentRound!;
      game.tapInstrument(round.loudSide);
      expect(game.needle, closeTo(1, 1e-9));
      game.tapInstrument(1 - round.loudSide);
      expect(game.needle, closeTo(-1, 1e-9));
      game.tapCharacter(piper: true);
      await tester.pump();
      expect(
        game.needle,
        closeTo(LoudQuietRound.needlePosition(round.gainOf(0)), 1e-9),
      );
      await _playThrough(tester);
      expect(game.needle, 0);
      game.dispose();
    });

    testWidgets('build 90\'s mode, behind the toggle: the prompt never moves '
        'the needle, a replay leaves it, and Decide taps leave it still; '
        'the round records the mode', (tester) async {
      final audio = _RecordingAudio();
      final game = LoudQuietGameState(
        audio: audio,
        random: math.Random(1),
        dialMode: DialMode.childTapsOnly,
      )..startGame();
      await tester.pump();
      expect(game.needle, 0);
      await _playThrough(tester);
      expect(game.needle, 0);
      final round = game.currentRound!;
      game.tapInstrument(round.loudSide);
      expect(game.needle, closeTo(1, 1e-9));
      game.tapCharacter(piper: true);
      await _playThrough(tester);
      expect(game.needle, closeTo(1, 1e-9));
      game.escape();
      expect(game.records.single.dialMode, 'childTapsOnly');
      game.dispose();

      final decide = LoudQuietGameState(
        audio: audio,
        random: math.Random(1),
        agencyStage: AgencyStage.decide,
        dialMode: DialMode.childTapsOnly,
      )..startGame();
      await _playThrough(tester);
      decide.tapInstrument(decide.currentRound!.loudSide);
      expect(decide.needle, 0);
      decide.dispose();
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

    testWidgets('Decide: a tap plays and moves the needle (card 208), but '
        'answers nothing', (tester) async {
      final audio = _RecordingAudio();
      final game = _game(audio, stage: AgencyStage.decide)..startGame();
      await _playThrough(tester);
      final round = game.currentRound!;
      final target = round.targetSide;
      for (var i = 0; i < 6; i++) {
        game.tapInstrument(target);
      }
      expect(
        game.needle,
        closeTo(LoudQuietRound.needlePosition(round.gainOf(target)), 1e-9),
      );
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
      await tester.pump(LoudQuietGameState.celebration);
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

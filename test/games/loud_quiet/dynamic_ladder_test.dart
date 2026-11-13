import 'dart:math' as math;

import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:ear_trainer/games/loud_quiet/state/loud_quiet_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loud or Quiet's own ladder: dynamic distance × instrument count (Trello
/// card 220).
void main() {
  const ladder = DynamicLadder.standard;

  test('six tiers, zigzag ordered: the third instrument arrives at EXTREME '
      'distance, never at the hardest one', () {
    expect(
      [
        for (var i = 0; i < ladder.length; i++)
          (ladder[i].distanceId, ladder.instrumentCountAt(i)),
      ],
      [
        ('extreme', 2),
        ('moderate', 2),
        ('subtle', 2),
        ('extreme', 3),
        ('moderate', 3),
        ('subtle', 3),
      ],
    );
    expect(ladder.distances.map((d) => d.gapDb), [12, 8, 4]);
  });

  test('one new demand per step: each step makes exactly one thing harder, '
      'or adds an instrument while relaxing the distance', () {
    for (var i = 1; i < ladder.length; i++) {
      final countUp =
          ladder.instrumentCountAt(i) > ladder.instrumentCountAt(i - 1);
      final narrower = ladder.gapDbAt(i) < ladder.gapDbAt(i - 1);
      expect(countUp != narrower, isTrue, reason: ladder.labelAt(i));
      if (countUp) {
        expect(ladder.gapDbAt(i), ladder.distances.first.gapDb);
      }
    }
  });

  test('NO THREE-INSTRUMENT ROUND AT OBSERVE — nor at Explore: as High vs '
      'Low, Observe holds at T1 and three instruments wait for Decide', () {
    for (var i = 0; i < ladder.length; i++) {
      final three = ladder.instrumentCountAt(i) == 3;
      expect(
        ladder.isReachableAt(i, AgencyStage.observe),
        i == 0,
        reason: ladder.labelAt(i),
      );
      expect(ladder.isReachableAt(i, AgencyStage.explore), !three);
      expect(ladder.isReachableAt(i, AgencyStage.decide), isTrue);
    }
  });

  test('the game enforces it on every path: asked for T6 at Observe it '
      'plays T1; at Explore, T3', () {
    final game = LoudQuietGameState(step: 5);
    game.agencyStage = AgencyStage.observe;
    expect(game.playedStep, 0);
    game.agencyStage = AgencyStage.explore;
    expect(game.playedStep, 2);
    game.dispose();
  });

  group('three instruments', () {
    LoudQuietRound round(int step, {bool asksLoud = true, int seed = 1}) =>
        LoudQuietRound.generate(
          ladder: ladder,
          step: step,
          asksLoud: asksLoud,
          random: math.Random(seed),
        );

    test('three DISTINCT levels, quiet at the floor, the same instrument '
        'and note on every side', () {
      for (final step in [3, 4, 5]) {
        final r = round(step);
        expect(r.sideCount, 3);
        expect(r.levelsDb.toSet(), hasLength(3));
        expect(r.quietDb, DynamicLadder.quietDb);
        expect(r.instruments.toSet(), hasLength(1));
      }
    });

    test("the tier's dB is the gap between NEIGHBOURS, never the total "
        'spread: T6 (subtle, 4) plays -12, -8, -4 — not -12, -10, -8', () {
      expect([...round(5).levelsDb]..sort(), [-12, -8, -4]);
      expect(round(5).gapDb, 4);
    });

    test('where the span will not hold the neighbour gap, it is COMPRESSED '
        'and recorded — never a silent relabel: T4 12→6, T5 8→6', () {
      expect(DynamicLadder.spanDb, 12);
      expect(ladder.playedGapDbAt(3), 6);
      expect(ladder.playedGapDbAt(4), 6);
      expect(ladder.playedGapDbAt(5), 4);
      expect(
        [for (var i = 0; i < 6; i++) ladder.isCompressedAt(i)],
        [false, false, false, true, true, false],
      );
      expect(ladder.playedGapsLabel(), '12 · 8 · 4 · 12→6 · 8→6 · 4');
      for (var i = 0; i < ladder.length; i++) {
        expect(ladder.loudDbAt(i), lessThanOrEqualTo(0), reason: 'no clip');
      }
    });

    test('the child picks the loudest or the quietest — never odd-one-out', () {
      for (var seed = 0; seed < 20; seed++) {
        final loud = round(3, seed: seed);
        expect(loud.levelDbOf(loud.targetSide), loud.levelsDb.reduce(math.max));
        final quiet = round(3, asksLoud: false, seed: seed);
        expect(
          quiet.levelDbOf(quiet.targetSide),
          quiet.levelsDb.reduce(math.min),
        );
      }
    });

    test('the loudest lands on every position over a session', () {
      final sides = {for (var s = 0; s < 40; s++) round(4, seed: s).loudSide};
      expect(sides, {0, 1, 2});
    });

    test('a Decide set at T4 plays three-instrument rounds', () {
      final game = LoudQuietGameState(agencyStage: AgencyStage.decide, step: 3)
        ..startGame();
      expect(game.currentRound!.sideCount, 3);
      game.dispose();
    });
  });

  test('TRAP 1: the gap closes by bringing LOUD down — quiet sits at the '
      'same level on every step', () {
    for (var i = 0; i < 3; i++) {
      final r = LoudQuietRound.generate(
        ladder: ladder,
        step: i,
        asksLoud: true,
        random: math.Random(i),
      );
      expect(r.quietDb, DynamicLadder.quietDb, reason: ladder.labelAt(i));
      expect(r.loudDb, DynamicLadder.quietDb + ladder.gapDbAt(i));
      expect(r.loudDb, lessThanOrEqualTo(0), reason: 'never above full');
    }
  });

  test("TRAP 2: trims go on each instrument's baseline before the gap — "
      "the gap heard between two instruments is the step's exactly", () {
    for (final (loud, quiet) in [
      (HighLowInstrument.oboe, HighLowInstrument.violin),
      (HighLowInstrument.violin, HighLowInstrument.oboe),
      (HighLowInstrument.guitar, HighLowInstrument.flute),
    ]) {
      final r = LoudQuietRound(
        leftInstrument: loud,
        rightInstrument: quiet,
        midi: 72,
        loudSide: 0,
        loudDb: ladder.loudDbAt(1),
        asksLoud: true,
      );
      double trim(HighLowInstrument i) =>
          LoudQuietRound.perceptualTrimDb[i] ?? 0;
      final heardGap =
          (r.playbackDbOf(0) - trim(loud)) - (r.playbackDbOf(1) - trim(quiet));
      expect(heardGap, closeTo(8, 1e-9), reason: '${loud.name}/${quiet.name}');
    }
  });

  test("TRAP 3: gaps are decibels, tuned per DISTANCE — a step's gap is "
      'the dB difference between the two levels, and every step at that '
      'distance moves with it', () {
    final tuned = ladder.withGap('moderate', 6.5);
    expect(tuned.gapDbAt(1), 6.5);
    expect(tuned.gapDbAt(4), 6.5, reason: 'T5 shares the distance');
    final r = LoudQuietRound.generate(
      ladder: tuned,
      step: 1,
      asksLoud: true,
      random: math.Random(1),
    );
    final db =
        20 *
        math.log(r.gainOf(r.loudSide) / r.gainOf(1 - r.loudSide)) /
        math.ln10;
    expect(db, closeTo(6.5, 1e-9));
  });

  test('LENGTH IS DATA: a shorter or longer ladder works, and a step past '
      'the end clamps onto it', () {
    final three = DynamicLadder(
      distances: ladder.distances,
      steps: ladder.steps.take(3).toList(),
    );
    expect(three.length, 3);
    expect(three[9].distanceId, 'subtle');
    final seven = DynamicLadder(
      distances: [...ladder.distances, const DynamicDistance('faint', 'F', 2)],
      steps: [...ladder.steps, const DynamicStep('faint', 2)],
    );
    expect(seven.loudDbAt(6), DynamicLadder.quietDb + 2);
  });

  test('a tuned gap stays within loud-at-full and the narrowest', () {
    expect(ladder.withGap('extreme', 20).gapDbAt(0), DynamicLadder.maxGapDb);
    expect(ladder.withGap('subtle', 0).gapDbAt(2), DynamicLadder.minGapDb);
  });

  group('tuned on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a gap set in the dev gate survives a relaunch, by distance id — '
        'so gaps tuned on the three-step ladder carry over', () async {
      SharedPreferences.setMockInitialValues({
        'dev.loudQuiet.gapsDb': '{"extreme":11,"moderate":7,"subtle":3}',
      });
      final dev = DevSettingsState();
      await dev.load();
      expect(dev.loudQuietLadder.gapDbAt(1), 7);
      expect(dev.loudQuietLadder.gapDbAt(4), 7);
      dev.setLoudQuietGap(2, 5);
      await Future<void>.delayed(Duration.zero);
      final relaunched = DevSettingsState();
      await relaunched.load();
      expect(relaunched.loudQuietLadder.gapDbAt(5), 5);
      expect(relaunched.loudQuietLadder.gapDbAt(0), 11);
    });
  });
}

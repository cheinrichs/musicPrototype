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
    // Recalibrated to Cooper's ear as the CEILING (2026-11-13): 8 is the
    // hardest rung — he found 4 indistinguishable and 6 "very tricky".
    expect(ladder.distances.map((d) => d.gapDb), [16, 12, 8]);
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
        expect(r.quietDb, DynamicLadder.floorDb);
        expect(r.instruments.toSet(), hasLength(1));
      }
    });

    test("the tier's dB is the TARGET's gap from its NEAREST COMPETITOR; "
        'the third sits a small fixed offset beyond — not even spacing', () {
      // T6 (subtle, 8), asking loudest: -12, -9, then the target at -1.
      expect([...round(5).levelsDb]..sort(), [-12, -9, -1]);
      expect(round(5).gapDb, 8);
      // Asking quietest, the mirror: the target on the floor.
      expect([...round(5, asksLoud: false).levelsDb]..sort(), [-12, -4, -1]);
      expect(round(5, asksLoud: false).gapDb, 8);
    });

    test('every round plays its tier\'s played gap between target and '
        'nearest competitor, whichever end is asked for', () {
      for (final step in [3, 4, 5]) {
        for (final asksLoud in [true, false]) {
          for (var seed = 0; seed < 10; seed++) {
            final r = round(step, asksLoud: asksLoud, seed: seed);
            expect(r.gapDb, ladder.playedGapDbAt(step));
          }
        }
      }
    });

    test('where the span holds it, a three-instrument tier is exactly as '
        'hard to discriminate as its twin: T6 = T3 = 8', () {
      expect(ladder.playedGapDbAt(5), ladder.playedGapDbAt(2));
      expect(ladder.isCompressedAt(5), isFalse);
    });

    test('THE TWO LADDERS DIVERGE: three need more span than two, so a ×3 '
        'tier can play narrower than its ×2 twin — recorded, not forced to '
        'match', () {
      expect(ladder.maxGapDbFor(2), 12);
      expect(ladder.maxGapDbFor(3), 9);
      expect(ladder.playedGapDbAt(1), 12, reason: 'T2, moderate ×2');
      expect(ladder.playedGapDbAt(4), 9, reason: 'T5, moderate ×3');
      expect(ladder.isCompressedAt(4), isTrue);
    });

    test('where the span will not hold the figure, it is COMPRESSED and '
        'recorded — never a silent relabel', () {
      expect(ladder.spanDb, 12);
      expect(
        [for (var i = 0; i < 6; i++) ladder.isCompressedAt(i)],
        [true, false, false, true, true, false],
      );
      expect(ladder.playedGapsLabel(), '16→12 · 12 · 8 · 16→9 · 12→9 · 8');
      for (var i = 0; i < ladder.length; i++) {
        for (final asksLoud in [true, false]) {
          final levels = ladder.levelsDbAt(i, asksLoud: asksLoud);
          expect(levels.first, ladder.quietDb, reason: 'quiet');
          expect(levels.last, lessThanOrEqualTo(0), reason: 'no clip');
          expect(levels.last, ladder.loudDbAt(i));
        }
      }
    });

    test('the three-instrument gap is tuned on its own: setting T5 to 5 dB '
        'leaves T2 at 12, and plays no wider than the span holds', () {
      final tuned = ladder.withGapAt(4, 5);
      expect(tuned.playedGapDbAt(4), 5);
      expect(tuned.isCompressedAt(4), isFalse);
      expect(tuned.gapDbAt(1), 12, reason: 'its two-instrument twin');
      expect(ladder.withGapAt(3, 11).playedGapDbAt(3), 9);
      expect(tuned.playedGapsLabel(), '16→12 · 12 · 8 · 16→9 · 5 · 8');
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
      expect(r.quietDb, DynamicLadder.floorDb, reason: ladder.labelAt(i));
      expect(r.loudDb, DynamicLadder.floorDb + ladder.playedGapDbAt(i));
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
      expect(heardGap, closeTo(12, 1e-9), reason: '${loud.name}/${quiet.name}');
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
    expect(seven.loudDbAt(6), DynamicLadder.floorDb + 2);
  });

  test('a tuned figure stays within the narrowest and the widest, and never '
      'PLAYS above full', () {
    final wide = ladder.withGap('extreme', 30);
    expect(wide.gapDbAt(0), DynamicLadder.maxFigureDb);
    expect(wide.loudDbAt(0), 0);
    expect(ladder.withGap('subtle', 0).gapDbAt(2), DynamicLadder.minGapDb);
  });

  group('the quiet sound lifted off the floor', () {
    test('every gap stays IDENTICAL — the whole pair moves up', () {
      final lifted = ladder.withLift(4);
      expect(lifted.quietDb, -8);
      expect(lifted.playedGapDbAt(2), 8, reason: 'T3 still 8');
      expect(lifted.levelsDbAt(2, asksLoud: true), [-8, 0]);
      final r = LoudQuietRound.generate(
        ladder: lifted,
        step: 2,
        asksLoud: true,
        random: math.Random(1),
      );
      expect(r.quietDb, -8);
      expect(r.gapDb, 8);
    });

    test('the span above shrinks dB for dB, and what no longer fits is '
        'compressed and says so', () {
      final lifted = ladder.withLift(4);
      expect(lifted.spanDb, 8);
      expect(lifted.maxGapDbFor(2), 8);
      expect(lifted.maxGapDbFor(3), 5);
      expect(lifted.playedGapsLabel(), '16→8 · 12→8 · 8 · 16→5 · 12→5 · 8→5');
    });

    test('kept within 0 and the most it may be lifted', () {
      expect(ladder.withLift(-3).liftDb, 0);
      expect(ladder.withLift(40).liftDb, DynamicLadder.maxLiftDb);
    });

    test('a gap tuned afterwards keeps the lift', () {
      expect(ladder.withLift(3).withGapAt(2, 7).liftDb, 3);
      expect(ladder.withLift(3).withGapAt(5, 4).liftDb, 3);
    });
  });

  group('tuned on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'a three-instrument gap set in the dev gate survives a relaunch',
      () async {
        final dev = DevSettingsState()..setAgencyStage(AgencyStage.decide);
        dev.setLoudQuietGap(4, 5);
        await Future<void>.delayed(Duration.zero);
        final relaunched = DevSettingsState();
        await relaunched.load();
        expect(relaunched.loudQuietLadder.playedGapDbAt(4), 5);
        expect(relaunched.loudQuietLadder.gapDbAt(1), 12);
      },
    );

    test('the lift set in the dev gate survives a relaunch', () async {
      final dev = DevSettingsState()..setLoudQuietLift(3);
      await Future<void>.delayed(Duration.zero);
      final relaunched = DevSettingsState();
      await relaunched.load();
      expect(relaunched.loudQuietLadder.liftDb, 3);
      expect(relaunched.loudQuietLadder.quietDb, -9);
      expect(dev.loudQuietLadder, relaunched.loudQuietLadder);
    });

    test('gaps tuned against the OLD 12/8/4 table are left behind — the '
        'recalibrated placeholders apply', () async {
      SharedPreferences.setMockInitialValues({
        'dev.loudQuiet.gapsDb': '{"extreme":11,"moderate":7,"subtle":3}',
      });
      final dev = DevSettingsState();
      await dev.load();
      expect(dev.loudQuietLadder, DynamicLadder.standard);
    });

    test(
      'a gap set in the dev gate survives a relaunch, by distance id',
      () async {
        final dev = DevSettingsState()..setAgencyStage(AgencyStage.decide);
        dev.setLoudQuietGap(2, 5);
        await Future<void>.delayed(Duration.zero);
        final relaunched = DevSettingsState();
        await relaunched.load();
        expect(relaunched.loudQuietLadder.gapDbAt(2), 5);
        expect(relaunched.loudQuietLadder.gapDbAt(0), 16);
      },
    );
  });
}

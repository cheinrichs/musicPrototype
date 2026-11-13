import 'dart:math' as math;

import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loud or Quiet's own ladder: dynamic distance (Trello card 220).
void main() {
  const ladder = DynamicLadder.standard;

  test('the starting table: extreme 12, moderate 8, subtle 4 dB, and the '
      'phrase step marked unbuilt', () {
    expect(ladder.steps.map((s) => s.gapDb).take(3), [12, 8, 4]);
    expect(ladder.steps.last.built, isFalse);
  });

  test('TRAP 1: the gap closes by bringing LOUD down — quiet sits at the '
      'same level on every step', () {
    for (var i = 0; i < ladder.length; i++) {
      final r = LoudQuietRound.generate(
        ladder: ladder,
        step: i,
        asksLoud: true,
        random: math.Random(i),
      );
      expect(r.quietDb, DynamicLadder.quietDb, reason: ladder[i].id);
      expect(r.loudDb, DynamicLadder.quietDb + ladder.playedAt(i).gapDb);
      expect(r.loudDb, lessThanOrEqualTo(0), reason: 'never above full');
    }
  });

  test('TRAP 2: trims go on each instrument\'s baseline before the gap — '
      'the gap heard between two instruments is the step\'s exactly', () {
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
      // Perceived level = played level minus the instrument's own trim.
      final heardGap =
          (r.playbackDbOf(0) - trim(loud)) - (r.playbackDbOf(1) - trim(quiet));
      expect(heardGap, closeTo(8, 1e-9), reason: '${loud.name}/${quiet.name}');
    }
  });

  test('TRAP 3: gaps are decibels — a step\'s gap is the dB difference '
      'between the two levels, whatever it is tuned to', () {
    final tuned = ladder.withGap(1, 6.5);
    expect(tuned.loudDbAt(1) - DynamicLadder.quietDb, 6.5);
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

  test('an unbuilt step plays as the built step below it', () {
    expect(ladder.playedAt(3).id, 'subtle');
    expect(ladder.loudDbAt(3), ladder.loudDbAt(2));
  });

  test('LENGTH IS DATA: a three-step ladder is as valid as four, and a '
      'step past the end clamps onto it', () {
    final three = DynamicLadder(ladder.steps.take(3).toList());
    expect(three.length, 3);
    expect(three.playedAt(7).id, 'subtle');
    final r = LoudQuietRound.generate(
      ladder: three,
      step: 9,
      asksLoud: false,
      random: math.Random(2),
    );
    expect(r.gapDb, 4);
  });

  test('a tuned gap stays within loud-at-full and the narrowest', () {
    expect(ladder.withGap(0, 20)[0].gapDb, DynamicLadder.maxGapDb);
    expect(ladder.withGap(2, 0)[2].gapDb, DynamicLadder.minGapDb);
  });

  group('tuned on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a gap set in the dev gate survives a relaunch, by step id', () async {
      final dev = DevSettingsState();
      dev.setLoudQuietGap(1, 7);
      await Future<void>.delayed(Duration.zero);
      final relaunched = DevSettingsState();
      await relaunched.load();
      expect(relaunched.loudQuietLadder[1].gapDb, 7);
      expect(relaunched.loudQuietLadder[0].gapDb, 12);
    });
  });
}

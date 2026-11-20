import 'dart:math' as math;

import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

/// An instrument's LOOKS (Cooper, 2026-11-14): one instrument on three
/// platforms must be three tellable-apart sprites. Appearance only.
void main() {
  test('THE SELECTION RULE, BY INDEX (Cooper, 2026-11-20): two positions '
      'use the OUTER pair, three use all three; the centre never appears in '
      'a two-instrument round', () {
    expect(HighLowInstrument.variantsFor(1), [0, 2]);
    expect(HighLowInstrument.variantsFor(2), [0, 2]);
    expect(HighLowInstrument.variantsFor(3), [0, 1, 2]);
    for (final i in HighLowInstrument.values) {
      final looks = i.looks;
      expect(looks, hasLength(3), reason: i.name);
      expect(looks.toSet(), hasLength(3), reason: '${i.name}: three distinct');
      expect(i.looksFor(2), [looks[0], looks[2]], reason: i.name);
      expect(i.looksFor(3), looks, reason: i.name);
      expect(i.looksFor(1), [looks[0]], reason: i.name);
      expect(i.hasDistinctLooksFor(3), isTrue, reason: i.name);
    }
  });

  test('a two-instrument round never draws a centre variant, whichever '
      'instruments it pairs', () {
    for (final a in HighLowInstrument.values) {
      for (final b in HighLowInstrument.values) {
        final looks = HighLowInstrument.looksForRound([a, b]);
        expect(
          looks,
          isNot(contains(a.looks[1])),
          reason: '${a.name}+${b.name}',
        );
        expect(
          looks,
          isNot(contains(b.looks[1])),
          reason: '${a.name}+${b.name}',
        );
      }
    }
  });

  test('one instrument on THREE positions: its three variants, left to '
      'right', () {
    for (final i in HighLowInstrument.values) {
      expect(HighLowInstrument.looksForRound(List.filled(3, i)), i.looks);
    }
  });

  test('two instruments in one round each keep their own looks apart', () {
    final looks = HighLowInstrument.looksForRound([
      HighLowInstrument.flute,
      HighLowInstrument.piano,
      HighLowInstrument.flute,
    ]);
    expect(looks, [
      HighLowInstrument.flute.looks[0],
      HighLowInstrument.piano.looks[0],
      HighLowInstrument.flute.looks[2],
    ]);
  });

  test('LOOKS NEVER TOUCH ELIGIBILITY: which instruments play a Loud or '
      'Quiet step is the room rule alone — bells with three looks are in '
      'exactly the steps their headroom reaches', () {
    const ladder = DynamicLadder.standard;
    for (var step = 0; step < ladder.length; step++) {
      expect(ladder.eligibleAt(step), [
        for (final i in DynamicLadder.poolFor(ladder.instrumentCountAt(step)))
          if (ladder.headroomOf(i) >= ladder.loudDbAt(step)) i,
      ]);
    }
    // Three-instrument rounds still leave the bells out (their half-size
    // art, not their looks).
    expect(DynamicLadder.poolFor(3), isNot(contains(HighLowInstrument.bells)));
  });

  group('the xylophone: a TRIAL instrument, dev profile only', () {
    tearDown(() => HighLowInstrument.trialsEnabled = false);

    test('OUT of every pool unless trials are on — a child never meets it', () {
      HighLowInstrument.trialsEnabled = false;
      expect(
        HighLowInstrument.inPlay,
        isNot(contains(HighLowInstrument.xylophone)),
      );
      expect(
        DynamicLadder.poolFor(2),
        isNot(contains(HighLowInstrument.xylophone)),
      );
      HighLowInstrument.trialsEnabled = true;
      expect(HighLowInstrument.inPlay, contains(HighLowInstrument.xylophone));
      expect(DynamicLadder.poolFor(2), contains(HighLowInstrument.xylophone));
    });

    test('with trials on, both games generate rounds with it, and Loud or '
        "Quiet keeps it to the levels its +0.5 dB room allows", () {
      HighLowInstrument.trialsEnabled = true;
      final generator = PromptGenerator(random: math.Random(7));
      var seen = false;
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 150; i++) {
          final p = generator.generatePrompt(
            promptNumber: i,
            tier: tier,
            targetDirection: PitchDirection.higher,
          );
          if (p.firstInstrument == HighLowInstrument.xylophone) seen = true;
        }
      }
      expect(seen, isTrue);
      const ladder = DynamicLadder.standard;
      for (var step = 0; step < ladder.length; step++) {
        expect(
          ladder.eligibleAt(step).contains(HighLowInstrument.xylophone),
          ladder.instrumentCountAt(step) >= 2 && ladder.loudDbAt(step) <= 0.5,
          reason: 'T${step + 1}',
        );
      }
    });
  });
}

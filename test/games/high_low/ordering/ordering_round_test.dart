import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_round.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

/// Every way to assign [n] notes to [n] distinct slots.
Iterable<List<int>> permutations(int n) sync* {
  Iterable<List<int>> go(List<int> rest, List<int> chosen) sync* {
    if (rest.isEmpty) {
      yield chosen;
      return;
    }
    for (final x in rest) {
      yield* go([...rest]..remove(x), [...chosen, x]);
    }
  }

  yield* go([for (var i = 0; i < n; i++) i], []);
}

OrderingRound roundOf(List<int> midis) => OrderingRound([
  for (final m in midis) (instrument: HighLowInstrument.piano, midi: m),
]);

void main() {
  group('OrderingRound', () {
    test('the highest note belongs on the top slot and the lowest on the '
        'bottom one, whatever order the notes were played in', () {
      final round = roundOf([64, 76, 70]); // played mid, high, low-ish
      // sorted high to low: 76 (index 1), 70 (index 2), 64 (index 0)
      expect(round.correctSlotOf(1), 0);
      expect(round.correctSlotOf(2), 1);
      expect(round.correctSlotOf(0), 2);
    });

    test('with three notes, exactly two correct is unreachable: two in '
        'their right places leaves the third nowhere else to go — so the '
        'only outcomes are 3, 1 or 0. A two-tick state would mean the '
        'checker is wrong', () {
      final round = roundOf([60, 67, 74]);
      final tally = <int, int>{};
      for (final perm in permutations(3)) {
        final placements = {
          for (var note = 0; note < 3; note++) note: perm[note],
        };
        final correct = round.correctNotes(placements).length;
        tally[correct] = (tally[correct] ?? 0) + 1;
      }
      expect(tally.keys.toSet(), {0, 1, 3}, reason: 'tally: $tally');
      expect(tally[3], 1, reason: 'one perfect ordering');
      expect(tally[1], 3, reason: 'a fixed point + the other two swapped');
      expect(tally[0], 2, reason: 'the two 3-cycles');
    });

    test('with two notes the outcomes are 2 or 0 — never one', () {
      final round = roundOf([60, 72]);
      final counts = {
        for (final perm in permutations(2))
          round.correctNotes({0: perm[0], 1: perm[1]}).length,
      };
      expect(counts, {0, 2});
    });

    test('a slot filled by the right instrument is correct on its own '
        'merits: partial placements are judged per note, and only full ones '
        'are ever evaluated by the state', () {
      final round = roundOf([60, 67, 74]);
      // 74 (index 2) is the highest → slot 0.
      expect(round.correctNotes({2: 0}), {2});
      expect(round.correctNotes({2: 1}), isEmpty);
    });

    test(
      'holds for every real generated prompt, at every three-note tier '
      '— generated notes never tie, so the ranking is always unambiguous',
      () {
        final generator = PromptGenerator(random: Random(3));
        for (final tier in [
          ConceptTier.t5,
          ConceptTier.t6,
          ConceptTier.t7,
          ConceptTier.t8,
        ]) {
          for (var i = 0; i < 100; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            final round = OrderingRound.fromPrompt(prompt);
            expect(round.notes.length, 3);
            expect(
              {for (var n = 0; n < 3; n++) round.correctSlotOf(n)},
              {0, 1, 2},
              reason: '$tier prompt $i: each note needs its own slot',
            );
            for (final perm in permutations(3)) {
              final placements = {for (var n = 0; n < 3; n++) n: perm[n]};
              expect(round.correctNotes(placements).length, isNot(2));
            }
          }
        }
      },
    );

    test('a two-note round uses the top two slots, leaving the bottom step '
        'empty — the same tree with one step unoccupied', () {
      final round = roundOf([60, 72]);
      expect(round.slotCount, 3);
      expect(round.activeSlots, [0, 1]);
      expect(round.correctSlotOf(1), 0);
      expect(round.correctSlotOf(0), 1);
    });
  });
}

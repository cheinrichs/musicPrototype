import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/concept_tier.dart';

void main() {
  group('ConceptTier', () {
    test('is the complete 2x2x2 ladder from docs/product/HIGH_LOW_TIERS.md '
        '— interval width, instrumentsVary, and noteCount together '
        'identify each tier uniquely', () {
      final shapes = {
        for (final tier in ConceptTier.values)
          tier: (tier.minSemitones, tier.instrumentsVary, tier.noteCount),
      };

      expect(shapes[ConceptTier.t1], (7, false, 2));
      expect(shapes[ConceptTier.t2], (4, false, 2));
      expect(shapes[ConceptTier.t3], (7, true, 2));
      expect(shapes[ConceptTier.t4], (4, true, 2));
      expect(shapes[ConceptTier.t5], (7, false, 3));
      expect(shapes[ConceptTier.t6], (4, false, 3));
      expect(shapes[ConceptTier.t7], (7, true, 3));
      expect(shapes[ConceptTier.t8], (4, true, 3));

      // Every (interval, instrumentsVary, noteCount) triple above is
      // distinct — a genuine 2x2x2 grid, not two tiers accidentally
      // sharing a cell (the exact bug this ladder replaced: the old
      // four-tier ConceptTier gave T3 the same range as T2).
      expect(shapes.values.toSet().length, 8);
    });

    test('wide tiers are 7-12 semitones, narrow tiers are 4-7 — nothing '
        'narrower than a major third exists anywhere, unlike the old '
        'four-tier ladder\'s 2-4 semitone T4', () {
      for (final tier in ConceptTier.values) {
        expect(tier.minSemitones, anyOf(4, 7));
        expect(tier.maxSemitones, anyOf(7, 12));
        expect(
          tier.minSemitones,
          greaterThanOrEqualTo(4),
          reason: '$tier allows an interval narrower than a major third',
        );
      }
    });

    test('instrument contrast turns off again at T5-T6 even though T3-T4 '
        'already turned it on — deliberate (see the class doc: a ladder '
        'that only accumulates features can\'t relax anything when a new '
        'demand arrives)', () {
      expect(ConceptTier.t3.instrumentsVary, isTrue);
      expect(ConceptTier.t4.instrumentsVary, isTrue);
      expect(ConceptTier.t5.instrumentsVary, isFalse);
      expect(ConceptTier.t6.instrumentsVary, isFalse);
      expect(ConceptTier.t7.instrumentsVary, isTrue);
      expect(ConceptTier.t8.instrumentsVary, isTrue);
    });

    test('the interval widens back to 7-12 at every tier that introduces '
        'a new demand — T3, T5, T7', () {
      for (final tier in [ConceptTier.t3, ConceptTier.t5, ConceptTier.t7]) {
        expect(
          tier.minSemitones,
          7,
          reason:
              '$tier introduces a new demand and should widen the '
              'interval back out, per the governing rule',
        );
      }
    });

    test('three notes arrives at T5, not before', () {
      for (final tier in [
        ConceptTier.t1,
        ConceptTier.t2,
        ConceptTier.t3,
        ConceptTier.t4,
      ]) {
        expect(tier.noteCount, 2, reason: '$tier should still be two notes');
      }
      for (final tier in [
        ConceptTier.t5,
        ConceptTier.t6,
        ConceptTier.t7,
        ConceptTier.t8,
      ]) {
        expect(tier.noteCount, 3, reason: '$tier should be three notes');
      }
    });

    test('labels are T1 through T8, in order', () {
      expect(ConceptTier.values.map((t) => t.label).toList(), [
        'T1',
        'T2',
        'T3',
        'T4',
        'T5',
        'T6',
        'T7',
        'T8',
      ]);
    });
  });
}

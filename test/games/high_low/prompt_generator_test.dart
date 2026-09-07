import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';

/// T1/T2/T5/T6 — same instrument, so [HighLowPrompt.secondInstrument]
/// (and [HighLowPrompt.thirdInstrument] for T5/T6) always equals
/// [HighLowPrompt.firstInstrument].
const sameInstrumentTiers = [
  ConceptTier.t1,
  ConceptTier.t2,
  ConceptTier.t5,
  ConceptTier.t6,
];

/// T3/T4/T7/T8 — a pair of different, pairable instruments.
const varyingInstrumentTiers = [
  ConceptTier.t3,
  ConceptTier.t4,
  ConceptTier.t7,
  ConceptTier.t8,
];

const twoNoteTiers = [
  ConceptTier.t1,
  ConceptTier.t2,
  ConceptTier.t3,
  ConceptTier.t4,
];
const threeNoteTiers = [
  ConceptTier.t5,
  ConceptTier.t6,
  ConceptTier.t7,
  ConceptTier.t8,
];

void main() {
  group('PromptGenerator', () {
    test('generates prompts with valid note pairs', () {
      final generator = PromptGenerator();
      final prompt = generator.generatePrompt(
        promptNumber: 1,
        tier: ConceptTier.t1,
        targetDirection: PitchDirection.higher,
      );

      expect(prompt.firstMidi, isNot(equals(prompt.secondMidi)));
      expect(prompt.promptNumber, equals(1));
      expect(prompt.targetDirection, equals(PitchDirection.higher));
    });

    test('generates correct number of prompts, one per target direction', () {
      final generator = PromptGenerator();
      final prompts = generator.generatePrompts(
        count: 10,
        tier: ConceptTier.t1,
        targetDirections: List.filled(10, PitchDirection.lower),
      );

      expect(prompts.length, equals(10));
      expect(
        prompts.every((p) => p.targetDirection == PitchDirection.lower),
        isTrue,
      );
    });

    group('same-instrument tiers (T1/T2/T5/T6)', () {
      test('never mixes instruments within a prompt', () {
        final generator = PromptGenerator(random: Random(1234));
        for (final tier in sameInstrumentTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(prompt.firstInstrument, equals(prompt.secondInstrument));
            if (prompt.isThreeNote) {
              expect(prompt.thirdInstrument, equals(prompt.firstInstrument));
            }
          }
        }
      });

      test('every note falls within the chosen instrument\'s own declared '
          'sample range — matters because guitar\'s declared range has '
          'two internal gaps (see HighLowInstrument\'s class doc) even '
          'though its span matches everyone else\'s', () {
        final generator = PromptGenerator(random: Random(99));
        for (final tier in sameInstrumentTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            final instrument = prompt.firstInstrument;
            final midis = [
              prompt.firstMidi,
              prompt.secondMidi,
              if (prompt.thirdMidi != null) prompt.thirdMidi!,
            ];
            for (final midi in midis) {
              expect(
                midi,
                inInclusiveRange(
                  instrument.lowestSampleMidi,
                  instrument.highestSampleMidi,
                ),
              );
              expect(instrument.missingMidis.contains(midi), isFalse);
            }
          }
        }
      });

      test('never selects an instrument whose own range is narrower than '
          'the tier needs — general invariant, not tuba-specific, added '
          'after a real T1 round on build 45 paired two tuba notes '
          '(D#2/A#2) a phone speaker couldn\'t reproduce clearly enough '
          'to compare', () {
        final generator = PromptGenerator(random: Random(555));
        for (final tier in sameInstrumentTiers) {
          for (var i = 0; i < 300; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(
              prompt.firstInstrument.hasRangeFor(tier.minSemitones),
              isTrue,
              reason:
                  '$tier picked ${prompt.firstInstrument}, whose range is '
                  'narrower than this tier\'s ${tier.minSemitones}-semitone '
                  'floor',
            );
          }
        }
      });

      test('tuba never appears, at any same-instrument tier — its post-'
          'audibility-cut range (3 semitones) clears none of the eight '
          'tiers\' floors (the narrowest is 4) now that the old T4\'s '
          '2-semitone band is gone', () {
        final generator = PromptGenerator(random: Random(777));
        for (final tier in sameInstrumentTiers) {
          for (var i = 0; i < 300; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(
              prompt.firstInstrument,
              isNot(HighLowInstrument.tuba),
              reason: 'tuba was picked for $tier, which it cannot satisfy',
            );
          }
        }
      });

      test('correctAnswer is higher when second note is higher', () {
        final generator = PromptGenerator();
        final prompts = generator.generatePrompts(
          count: 50,
          tier: ConceptTier.t1,
          targetDirections: List.filled(50, PitchDirection.higher),
        );

        for (final prompt in prompts) {
          if (prompt.secondMidi > prompt.firstMidi) {
            expect(prompt.correctAnswer.name, equals('higher'));
          } else {
            expect(prompt.correctAnswer.name, equals('lower'));
          }
        }
      });

      test(
        'targetSide follows targetDirection, not correctAnswer directly',
        () {
          final generator = PromptGenerator(random: Random(7));
          for (var i = 0; i < 50; i++) {
            final promptAskingHigh = generator.generatePrompt(
              promptNumber: i,
              tier: ConceptTier.t1,
              targetDirection: PitchDirection.higher,
            );
            expect(
              promptAskingHigh.targetSide,
              equals(promptAskingHigh.higherSide),
            );

            final promptAskingLow = generator.generatePrompt(
              promptNumber: i,
              tier: ConceptTier.t1,
              targetDirection: PitchDirection.lower,
            );
            expect(
              promptAskingLow.targetSide,
              equals(1 - promptAskingLow.higherSide),
            );
          }
        },
      );

      test('T1 produces larger intervals on average than T2', () {
        final generator = PromptGenerator(random: Random(42));

        var t1Total = 0;
        var t2Total = 0;
        for (var i = 0; i < 50; i++) {
          t1Total += generator
              .generatePrompt(
                promptNumber: i,
                tier: ConceptTier.t1,
                targetDirection: PitchDirection.higher,
              )
              .difficulty;
          t2Total += generator
              .generatePrompt(
                promptNumber: i,
                tier: ConceptTier.t2,
                targetDirection: PitchDirection.higher,
              )
              .difficulty;
        }
        expect(t1Total / 50, greaterThan(t2Total / 50));
      });
    });

    group('cross-instrument tiers (T3/T4/T7/T8)', () {
      test('a two-note prompt (T3/T4) always mixes two different, '
          'pairable instruments', () {
        final generator = PromptGenerator(random: Random(2468));
        for (final tier in [ConceptTier.t3, ConceptTier.t4]) {
          for (var i = 0; i < 100; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(
              prompt.firstInstrument,
              isNot(prompt.secondInstrument),
              reason: '$tier prompt $i used the same instrument twice',
            );
            expect(
              prompt.firstInstrument.canPairWith(
                prompt.secondInstrument,
                minSemitones: tier.minSemitones,
              ),
              isTrue,
            );
          }
        }
      });

      test('a three-note prompt (T7/T8) always uses exactly two distinct, '
          'pairable instruments across its three notes — "varying" means '
          'more than one instrument sounds, not that every adjacent pair '
          'of positions must differ (unlike the two-note case, three '
          'notes drawn from a two-instrument pair can\'t all differ '
          'pairwise without a third instrument, which this tier doesn\'t '
          'introduce)', () {
        final generator = PromptGenerator(random: Random(9753));
        for (final tier in [ConceptTier.t7, ConceptTier.t8]) {
          for (var i = 0; i < 100; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            final instruments = {
              prompt.firstInstrument,
              prompt.secondInstrument,
              prompt.thirdInstrument!,
            };
            expect(
              instruments.length,
              2,
              reason:
                  '$tier prompt $i used ${instruments.length} distinct '
                  'instruments, expected exactly 2',
            );
            final [a, b] = instruments.toList();
            expect(a.canPairWith(b, minSemitones: tier.minSemitones), isTrue);
          }
        }
      });

      test('every note falls within its own instrument\'s declared sample '
          'range', () {
        final generator = PromptGenerator(random: Random(31));
        for (final tier in varyingInstrumentTiers) {
          for (var i = 0; i < 100; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            for (final (instrument, midi) in [
              (prompt.firstInstrument, prompt.firstMidi),
              (prompt.secondInstrument, prompt.secondMidi),
              if (prompt.thirdInstrument != null)
                (prompt.thirdInstrument!, prompt.thirdMidi!),
            ]) {
              expect(
                midi,
                inInclusiveRange(
                  instrument.lowestSampleMidi,
                  instrument.highestSampleMidi,
                ),
              );
              expect(instrument.missingMidis.contains(midi), isFalse);
            }
          }
        }
      });

      test('bells never appears — its C6-C7 range (84-96) doesn\'t overlap '
          'any other instrument\'s range at all, so it can never satisfy '
          'the overlap rule (falls out of the arithmetic, no special '
          'case needed)', () {
        final generator = PromptGenerator(random: Random(2026));
        for (final tier in varyingInstrumentTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            for (final instrument in [
              prompt.firstInstrument,
              prompt.secondInstrument,
              if (prompt.thirdInstrument != null) prompt.thirdInstrument!,
            ]) {
              expect(instrument, isNot(HighLowInstrument.bells));
            }
          }
        }
      });

      test('tuba never appears — its only possible partner (guitar) '
          'overlaps by just 3 semitones, under every tier\'s 4-semitone '
          'floor now that the narrowest band is gone', () {
        final generator = PromptGenerator(random: Random(4242));
        for (final tier in varyingInstrumentTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            for (final instrument in [
              prompt.firstInstrument,
              prompt.secondInstrument,
              if (prompt.thirdInstrument != null) prompt.thirdInstrument!,
            ]) {
              expect(instrument, isNot(HighLowInstrument.tuba));
            }
          }
        }
      });

      test('each instrument in a legal pairing appears as the higher note '
          'sometimes — the overlap rule\'s whole point is that "which '
          'instrument played" is never a giveaway for who\'s higher '
          '(2-note tiers only, where "higher" is well defined)', () {
        final generator = PromptGenerator(random: Random(13));
        for (final tier in [ConceptTier.t3, ConceptTier.t4]) {
          final higherInstruments = <HighLowInstrument>{};
          for (var i = 0; i < 300; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            higherInstruments.add(
              prompt.leftIsHigher
                  ? prompt.firstInstrument
                  : prompt.secondInstrument,
            );
          }
          expect(
            higherInstruments.length,
            greaterThan(1),
            reason:
                '$tier: only one instrument was ever the higher note in '
                '300 tries — that would be a giveaway',
          );
        }
      });
    });

    group('two-note tiers (T1/T2/T3/T4)', () {
      test('difficulty never falls outside the tier\'s bounds', () {
        final generator = PromptGenerator(random: Random(123));
        for (final tier in twoNoteTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(
              prompt.difficulty,
              inInclusiveRange(tier.minSemitones, tier.maxSemitones),
              reason: '$tier prompt $i had difficulty ${prompt.difficulty}',
            );
          }
        }
      });

      test('never has a third note', () {
        final generator = PromptGenerator(random: Random(321));
        for (final tier in twoNoteTiers) {
          for (var i = 0; i < 50; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(prompt.isThreeNote, isFalse);
          }
        }
      });
    });

    group('three-note tiers (T5/T6/T7/T8)', () {
      test('always has a third note, and every adjacent gap in sorted '
          'pitch order is within the tier\'s bounds', () {
        final generator = PromptGenerator(random: Random(654));
        for (final tier in threeNoteTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            expect(prompt.isThreeNote, isTrue);
            final sorted = prompt.sortedMidis;
            expect(sorted.toSet().length, 3, reason: 'notes must be distinct');
            for (var j = 1; j < sorted.length; j++) {
              final gap = sorted[j] - sorted[j - 1];
              expect(
                gap,
                inInclusiveRange(tier.minSemitones, tier.maxSemitones),
                reason: '$tier prompt $i had an adjacent gap of $gap',
              );
            }
          }
        }
      });

      test('highestIndex always points at the actual highest of the three '
          'real pitches, wherever it landed', () {
        final generator = PromptGenerator(random: Random(159));
        for (final tier in threeNoteTiers) {
          for (var i = 0; i < 200; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            final midis = [
              prompt.firstMidi,
              prompt.secondMidi,
              prompt.thirdMidi!,
            ];
            final expected = midis.indexOf(midis.reduce(max));
            expect(prompt.highestIndex, expected);
          }
        }
      });

      test('the highest note doesn\'t always land in the same position — '
          'a fixed slot would be a giveaway for "which one is highest" '
          'without listening', () {
        final generator = PromptGenerator(random: Random(753));
        for (final tier in threeNoteTiers) {
          final positions = <int>{};
          for (var i = 0; i < 100; i++) {
            final prompt = generator.generatePrompt(
              promptNumber: i,
              tier: tier,
              targetDirection: PitchDirection.higher,
            );
            positions.add(prompt.highestIndex);
          }
          expect(
            positions.length,
            greaterThan(1),
            reason:
                '$tier: the highest note landed in the same position every '
                'time in 100 tries',
          );
        }
      });
    });
  });
}

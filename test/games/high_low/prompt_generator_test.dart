import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';

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

    test('both notes always fall within the chosen instrument\'s own '
        'declared sample range, for every tier — this matters now that '
        'not every instrument has the same two-octave range (guitar and '
        'tuba are narrower; see HighLowInstrument\'s class doc)', () {
      final generator = PromptGenerator(random: Random(99));
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 200; i++) {
          final prompt = generator.generatePrompt(
            promptNumber: i,
            tier: tier,
            targetDirection: PitchDirection.higher,
          );
          final instrument = prompt.firstInstrument;
          expect(
            prompt.firstMidi,
            inInclusiveRange(
              instrument.lowestSampleMidi,
              instrument.highestSampleMidi,
            ),
          );
          expect(
            prompt.secondMidi,
            inInclusiveRange(
              instrument.lowestSampleMidi,
              instrument.highestSampleMidi,
            ),
          );
        }
      }
    });

    test('difficulty never falls outside the tier\'s bounds, even for an '
        'instrument whose range is narrower than the tier\'s max interval '
        '(guitar\'s 11-semitone span is smaller than T1\'s 12-semitone '
        'max)', () {
      final generator = PromptGenerator(random: Random(123));
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 200; i++) {
          final prompt = generator.generatePrompt(
            promptNumber: i,
            tier: tier,
            targetDirection: PitchDirection.higher,
          );
          final instrument = prompt.firstInstrument;
          final span =
              instrument.highestSampleMidi - instrument.lowestSampleMidi;
          final expectedMin = min(tier.minSemitones, span);
          final expectedMax = min(tier.maxSemitones, span);
          expect(
            prompt.difficulty,
            inInclusiveRange(expectedMin, expectedMax),
            reason:
                '$tier on $instrument (span $span) prompt $i had '
                'difficulty ${prompt.difficulty}',
          );
        }
      }
    });

    test('T4 never produces less than a 2-semitone gap', () {
      final generator = PromptGenerator(random: Random(42));

      for (var i = 0; i < 100; i++) {
        final prompt = generator.generatePrompt(
          promptNumber: i,
          tier: ConceptTier.t4,
          targetDirection: PitchDirection.higher,
        );
        expect(
          prompt.difficulty,
          greaterThanOrEqualTo(2),
          reason: 'Prompt $i had difficulty ${prompt.difficulty}',
        );
      }
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

    test('T1 produces larger intervals on average than T4', () {
      final generator = PromptGenerator(random: Random(42));

      var t1TotalInterval = 0;
      var t4TotalInterval = 0;

      for (var i = 0; i < 50; i++) {
        final easyPrompt = generator.generatePrompt(
          promptNumber: i,
          tier: ConceptTier.t1,
          targetDirection: PitchDirection.higher,
        );
        final hardPrompt = generator.generatePrompt(
          promptNumber: i,
          tier: ConceptTier.t4,
          targetDirection: PitchDirection.higher,
        );

        t1TotalInterval += easyPrompt.difficulty;
        t4TotalInterval += hardPrompt.difficulty;
      }

      expect(t1TotalInterval / 50, greaterThan(t4TotalInterval / 50));
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

    test('never mixes instruments within a pair, at any tier '
        '(a High/Low round is always two notes on one instrument)', () {
      final generator = PromptGenerator(random: Random(1234));

      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 200; i++) {
          final prompt = generator.generatePrompt(
            promptNumber: i,
            tier: tier,
            targetDirection: PitchDirection.higher,
          );
          expect(
            prompt.firstInstrument,
            equals(prompt.secondInstrument),
            reason:
                '$tier prompt $i mixed ${prompt.firstInstrument} with '
                '${prompt.secondInstrument}',
          );
        }
      }
    });

    test('targetSide follows targetDirection, not correctAnswer directly', () {
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
    });
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
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
        'declared sample range, for every tier — this matters because '
        'guitar\'s declared range has two internal gaps (see '
        'HighLowInstrument\'s class doc) even though its span matches '
        'everyone else\'s', () {
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

    test('never lands on one of guitar\'s missing notes (A3, A#4) — a '
        'raw-offset picker could hit these even though they\'re inside '
        'guitar\'s declared range; enumerating availableMidis pairs '
        'cannot', () {
      final generator = PromptGenerator(random: Random(2026));
      final guitar = HighLowInstrument.guitar;
      var sawGuitar = false;
      for (var i = 0; i < 2000; i++) {
        final prompt = generator.generatePrompt(
          promptNumber: i,
          tier: ConceptTier.t1,
          targetDirection: PitchDirection.higher,
        );
        if (prompt.firstInstrument != guitar) continue;
        sawGuitar = true;
        for (final midi in [prompt.firstMidi, prompt.secondMidi]) {
          expect(
            guitar.missingMidis.contains(midi),
            isFalse,
            reason: 'guitar prompt $i used missing MIDI $midi',
          );
        }
      }
      expect(
        sawGuitar,
        isTrue,
        reason: 'guitar never got picked in 2000 tries',
      );
    });

    test('difficulty never falls outside the tier\'s bounds, for every '
        'instrument\'s own declared span', () {
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

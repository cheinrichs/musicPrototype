import 'dart:math';

import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/match_note/services/match_note_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchNoteGenerator', () {
    late MatchNoteGenerator generator;

    setUp(() {
      // Use a seeded random for reproducible tests
      generator = MatchNoteGenerator(random: Random(42));
    });

    test('generates correct number of prompts', () {
      final prompts = generator.generatePrompts(count: 10);

      expect(prompts.length, 10);
    });

    test('each prompt has exactly 3 choices', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        expect(prompt.choiceCount, 3);
        expect(prompt.choices.length, 3);
      }
    });

    test('target note is always in choices', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        expect(
          prompt.choices.contains(prompt.targetNote),
          true,
          reason: 'Target note should be in choices',
        );
      }
    });

    test('correct index points to target note', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        expect(
          prompt.choices[prompt.correctIndex],
          prompt.targetNote,
          reason: 'Correct index should point to target note',
        );
      }
    });

    test('all choices are distinct notes', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        final uniqueChoices = prompt.choices.toSet();
        expect(
          uniqueChoices.length,
          3,
          reason: 'All 3 choices should be distinct notes',
        );
      }
    });

    test('correct index is valid (0, 1, or 2)', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        expect(prompt.correctIndex >= 0, true);
        expect(prompt.correctIndex <= 2, true);
      }
    });

    test('prompts have correct prompt numbers', () {
      final prompts = generator.generatePrompts(count: 10);

      for (int i = 0; i < prompts.length; i++) {
        expect(prompts[i].promptNumber, i + 1);
      }
    });

    test('isCorrect returns true only for correct index', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        // Only the correct index should return true
        expect(prompt.isCorrect(prompt.correctIndex), true);

        // Other indices should return false
        for (int i = 0; i < 3; i++) {
          if (i != prompt.correctIndex) {
            expect(prompt.isCorrect(i), false);
          }
        }
      }
    });

    test('all generated notes are within valid range', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        for (final choice in prompt.choices) {
          // Our Note enum has MIDI numbers from 60 (C4) to 83 (B5)
          expect(choice.midiNumber >= 60, true);
          expect(choice.midiNumber <= 83, true);
        }
      }
    });

    test('correct index distribution is roughly uniform', () {
      // With 100 prompts, we should see a reasonable distribution
      final prompts = generator.generatePrompts(count: 100);

      final indexCounts = [0, 0, 0];
      for (final prompt in prompts) {
        indexCounts[prompt.correctIndex]++;
      }

      // Each index should appear at least 20 times out of 100
      for (int i = 0; i < 3; i++) {
        expect(
          indexCounts[i] >= 20,
          true,
          reason:
              'Index $i appeared ${indexCounts[i]} times, expected at least 20',
        );
      }
    });
  });
}

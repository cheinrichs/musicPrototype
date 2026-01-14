import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';

void main() {
  group('PromptGenerator', () {
    test('generates prompts with valid note pairs', () {
      final generator = PromptGenerator();
      final prompt = generator.generatePrompt(promptNumber: 1);

      expect(prompt.firstNote, isNot(equals(prompt.secondNote)));
      expect(prompt.promptNumber, equals(1));
    });

    test('ensures minimum semitone distance of 2', () {
      final generator = PromptGenerator(
        random: Random(42),
      ); // Seeded for reproducibility

      for (var i = 0; i < 100; i++) {
        final prompt = generator.generatePrompt(promptNumber: i, difficulty: 5);
        expect(
          prompt.difficulty,
          greaterThanOrEqualTo(2),
          reason: 'Prompt $i had difficulty ${prompt.difficulty}',
        );
      }
    });

    test('generates correct number of prompts', () {
      final generator = PromptGenerator();
      final prompts = generator.generatePrompts(count: 10);

      expect(prompts.length, equals(10));
    });

    test('higher difficulty produces smaller intervals', () {
      final generator = PromptGenerator(random: Random(42));

      var easyTotalInterval = 0;
      var hardTotalInterval = 0;

      for (var i = 0; i < 50; i++) {
        final easyPrompt = generator.generatePrompt(
          promptNumber: i,
          difficulty: 1,
        );
        final hardPrompt = generator.generatePrompt(
          promptNumber: i,
          difficulty: 5,
        );

        easyTotalInterval += easyPrompt.difficulty;
        hardTotalInterval += hardPrompt.difficulty;
      }

      // Easy prompts should have larger intervals on average
      expect(easyTotalInterval / 50, greaterThan(hardTotalInterval / 50));
    });

    test('correctAnswer is higher when second note is higher', () {
      final generator = PromptGenerator();
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        if (prompt.secondNote.midiNumber > prompt.firstNote.midiNumber) {
          expect(prompt.correctAnswer.name, equals('higher'));
        } else {
          expect(prompt.correctAnswer.name, equals('lower'));
        }
      }
    });
  });
}

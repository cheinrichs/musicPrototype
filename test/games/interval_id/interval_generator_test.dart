import 'dart:math';

import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/interval_id/services/interval_generator.dart';
import 'package:ear_trainer/models/interval_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntervalGenerator', () {
    late IntervalGenerator generator;

    setUp(() {
      // Use a seeded random for reproducible tests
      generator = IntervalGenerator(random: Random(42));
    });

    test('generates correct number of prompts', () {
      final prompts = generator.generatePrompts(count: 10);

      expect(prompts.length, 10);
    });

    test('second note is correct semitones above root', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        final allNotes = Note.values;
        final rootIndex = allNotes.indexOf(prompt.rootNote);
        final secondIndex = allNotes.indexOf(prompt.secondNote);
        final actualSemitones = secondIndex - rootIndex;

        expect(
          actualSemitones,
          prompt.intervalType.semitones,
          reason:
              'Interval ${prompt.intervalType.shortLabel} should be ${prompt.intervalType.semitones} semitones',
        );
      }
    });

    test('all notes are within valid range', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        // Our Note enum has MIDI numbers from 60 (C4) to 83 (B5)
        expect(prompt.rootNote.midiNumber >= 60, true);
        expect(prompt.rootNote.midiNumber <= 83, true);
        expect(prompt.secondNote.midiNumber >= 60, true);
        expect(prompt.secondNote.midiNumber <= 83, true);
      }
    });

    test('second note is always higher than root', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        expect(
          prompt.secondNote.midiNumber > prompt.rootNote.midiNumber,
          true,
          reason: 'Second note should always be higher than root',
        );
      }
    });

    test('isCorrect returns true only for correct interval type', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        // Only the correct interval type should return true
        expect(prompt.isCorrect(prompt.intervalType), true);

        // Other interval types should return false
        for (final intervalType in IntervalType.values) {
          if (intervalType != prompt.intervalType) {
            expect(prompt.isCorrect(intervalType), false);
          }
        }
      }
    });

    test('prompts have correct prompt numbers', () {
      final prompts = generator.generatePrompts(count: 10);

      for (int i = 0; i < prompts.length; i++) {
        expect(prompts[i].promptNumber, i + 1);
      }
    });

    test('all 4 interval types are generated over many prompts', () {
      final prompts = generator.generatePrompts(count: 100);

      final typeCounts = <IntervalType, int>{};
      for (final prompt in prompts) {
        typeCounts[prompt.intervalType] =
            (typeCounts[prompt.intervalType] ?? 0) + 1;
      }

      // All 4 interval types should appear
      expect(typeCounts.length, 4);
      for (final type in IntervalType.values) {
        expect(
          typeCounts.containsKey(type),
          true,
          reason: '${type.displayName} should be generated',
        );
      }
    });

    test('semitones getter returns correct value', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        expect(prompt.semitones, prompt.intervalType.semitones);
      }
    });

    test('correctAnswer returns intervalType', () {
      final prompts = generator.generatePrompts(count: 10);

      for (final prompt in prompts) {
        expect(prompt.correctAnswer, prompt.intervalType);
      }
    });
  });
}

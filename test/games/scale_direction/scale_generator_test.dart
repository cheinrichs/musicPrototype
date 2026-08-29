import 'dart:math';

import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/scale_direction/services/scale_generator.dart';
import 'package:ear_trainer/models/scale_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScaleGenerator', () {
    late ScaleGenerator generator;

    setUp(() {
      // Use a seeded random for reproducible tests
      generator = ScaleGenerator(random: Random(42));
    });

    test('generates correct number of prompts', () {
      final prompts = generator.generatePrompts(count: 10);

      expect(prompts.length, 10);
    });

    test('each prompt has 3 notes (root, major 2nd, major 3rd)', () {
      final prompts = generator.generatePrompts(count: 10);

      for (final prompt in prompts) {
        expect(prompt.scaleNotes.length, 3);
      }
    });

    test('ascending scales have increasing pitch', () {
      // Generate many prompts to ensure we get ascending ones
      final prompts = generator.generatePrompts(count: 50);
      final ascendingPrompts = prompts.where(
        (p) => p.direction == ScaleDirection.ascending,
      );

      expect(ascendingPrompts.isNotEmpty, true);

      for (final prompt in ascendingPrompts) {
        final notes = prompt.scaleNotes;
        for (int i = 1; i < notes.length; i++) {
          expect(
            notes[i].midiNumber > notes[i - 1].midiNumber,
            true,
            reason:
                'Ascending scale note $i should be higher than note ${i - 1}',
          );
        }
      }
    });

    test('descending scales have decreasing pitch', () {
      // Generate many prompts to ensure we get descending ones
      final prompts = generator.generatePrompts(count: 50);
      final descendingPrompts = prompts.where(
        (p) => p.direction == ScaleDirection.descending,
      );

      expect(descendingPrompts.isNotEmpty, true);

      for (final prompt in descendingPrompts) {
        final notes = prompt.scaleNotes;
        for (int i = 1; i < notes.length; i++) {
          expect(
            notes[i].midiNumber < notes[i - 1].midiNumber,
            true,
            reason:
                'Descending scale note $i should be lower than note ${i - 1}',
          );
        }
      }
    });

    test('major scale intervals are correct for ascending', () {
      // Root, major 2nd, major 3rd: 0, 2, 4 semitones from root
      final prompts = generator.generatePrompts(count: 50);
      final ascendingPrompts = prompts.where(
        (p) => p.direction == ScaleDirection.ascending,
      );

      for (final prompt in ascendingPrompts) {
        final notes = prompt.scaleNotes;
        final rootMidi = notes.first.midiNumber;

        final expectedIntervals = [0, 2, 4];
        for (int i = 0; i < notes.length; i++) {
          final actualInterval = notes[i].midiNumber - rootMidi;
          expect(
            actualInterval,
            expectedIntervals[i],
            reason:
                'Note $i should be ${expectedIntervals[i]} semitones from root',
          );
        }
      }
    });

    test('major scale intervals are correct for descending', () {
      // Descending: 0, -2, -4 semitones from root
      final prompts = generator.generatePrompts(count: 50);
      final descendingPrompts = prompts.where(
        (p) => p.direction == ScaleDirection.descending,
      );

      for (final prompt in descendingPrompts) {
        final notes = prompt.scaleNotes;
        final rootMidi = notes.first.midiNumber;

        final expectedIntervals = [0, -2, -4];
        for (int i = 0; i < notes.length; i++) {
          final actualInterval = notes[i].midiNumber - rootMidi;
          expect(
            actualInterval,
            expectedIntervals[i],
            reason:
                'Note $i should be ${expectedIntervals[i]} semitones from root',
          );
        }
      }
    });

    test('all generated notes are within valid range', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        for (final note in prompt.scaleNotes) {
          // Our Note enum has MIDI numbers from 60 (C4) to 83 (B5)
          expect(note.midiNumber >= 60, true);
          expect(note.midiNumber <= 83, true);
        }
      }
    });

    test('prompts have correct prompt numbers', () {
      final prompts = generator.generatePrompts(count: 10);

      for (int i = 0; i < prompts.length; i++) {
        expect(prompts[i].promptNumber, i + 1);
      }
    });

    test('generates roughly equal ascending and descending', () {
      // With 100 prompts, we should have a reasonable distribution
      final prompts = generator.generatePrompts(count: 100);

      final ascendingCount = prompts
          .where((p) => p.direction == ScaleDirection.ascending)
          .length;
      final descendingCount = prompts.length - ascendingCount;

      // Should be at least 30% each direction (not too imbalanced)
      expect(ascendingCount >= 30, true);
      expect(descendingCount >= 30, true);
    });
  });
}

import 'dart:math';

import 'package:ear_trainer/audio/note.dart';
import 'package:ear_trainer/games/chord_id/services/chord_generator.dart';
import 'package:ear_trainer/models/chord_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChordGenerator', () {
    late ChordGenerator generator;

    setUp(() {
      // Use a seeded random for reproducible tests
      generator = ChordGenerator(random: Random(42));
    });

    test('generates correct number of prompts', () {
      final prompts = generator.generatePrompts(count: 10);

      expect(prompts.length, 10);
    });

    test('each chord has 3 notes', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        expect(
          prompt.chordNotes.length,
          3,
          reason: 'Each chord should have exactly 3 notes (root, 3rd, 5th)',
        );
      }
    });

    test('chord notes have correct intervals from root', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        final allNotes = Note.values;
        final rootIndex = allNotes.indexOf(prompt.rootNote);

        // First note should be the root
        expect(prompt.chordNotes[0], prompt.rootNote);

        // Second note should be the third (3 or 4 semitones)
        final thirdIndex = allNotes.indexOf(prompt.chordNotes[1]);
        final thirdInterval = thirdIndex - rootIndex;
        if (prompt.chordType == ChordType.major) {
          expect(thirdInterval, 4, reason: 'Major chord should have major 3rd');
        } else {
          expect(thirdInterval, 3, reason: 'Minor chord should have minor 3rd');
        }

        // Third note should be the fifth (7 semitones)
        final fifthIndex = allNotes.indexOf(prompt.chordNotes[2]);
        final fifthInterval = fifthIndex - rootIndex;
        expect(fifthInterval, 7, reason: 'Both chords should have perfect 5th');
      }
    });

    test('all notes are within valid range', () {
      final prompts = generator.generatePrompts(count: 50);

      for (final prompt in prompts) {
        for (final note in prompt.chordNotes) {
          // Our Note enum has MIDI numbers from 60 (C4) to 83 (B5)
          expect(note.midiNumber >= 60, true);
          expect(note.midiNumber <= 83, true);
        }
      }
    });

    test('isCorrect returns true only for correct chord type', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        // Only the correct chord type should return true
        expect(prompt.isCorrect(prompt.chordType), true);

        // The other chord type should return false
        for (final chordType in ChordType.values) {
          if (chordType != prompt.chordType) {
            expect(prompt.isCorrect(chordType), false);
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

    test('both chord types are generated over many prompts', () {
      final prompts = generator.generatePrompts(count: 100);

      final typeCounts = <ChordType, int>{};
      for (final prompt in prompts) {
        typeCounts[prompt.chordType] = (typeCounts[prompt.chordType] ?? 0) + 1;
      }

      // Both chord types should appear
      expect(typeCounts.length, 2);
      expect(
        typeCounts.containsKey(ChordType.major),
        true,
        reason: 'Major chords should be generated',
      );
      expect(
        typeCounts.containsKey(ChordType.minor),
        true,
        reason: 'Minor chords should be generated',
      );
    });

    test('correctAnswer returns chordType', () {
      final prompts = generator.generatePrompts(count: 10);

      for (final prompt in prompts) {
        expect(prompt.correctAnswer, prompt.chordType);
      }
    });

    test('root note matches first chord note', () {
      final prompts = generator.generatePrompts(count: 20);

      for (final prompt in prompts) {
        expect(
          prompt.chordNotes.first,
          prompt.rootNote,
          reason: 'Root note should be the first note in the chord',
        );
      }
    });
  });
}

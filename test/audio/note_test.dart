import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/note.dart';

void main() {
  group('Note', () {
    test('has correct MIDI numbers', () {
      expect(Note.c4.midiNumber, equals(60));
      expect(Note.a4.midiNumber, equals(69));
      expect(Note.c5.midiNumber, equals(72));
      expect(Note.b5.midiNumber, equals(83));
    });

    test('isHigherThan returns correct result', () {
      expect(Note.c5.isHigherThan(Note.c4), isTrue);
      expect(Note.c4.isHigherThan(Note.c5), isFalse);
      expect(Note.a4.isHigherThan(Note.g4), isTrue);
    });

    test('isLowerThan returns correct result', () {
      expect(Note.c4.isLowerThan(Note.c5), isTrue);
      expect(Note.c5.isLowerThan(Note.c4), isFalse);
    });

    test('intervalTo calculates correct semitone distance', () {
      expect(Note.c4.intervalTo(Note.c5), equals(12)); // Octave
      expect(Note.c4.intervalTo(Note.g4), equals(7)); // Perfect 5th
      expect(Note.c4.intervalTo(Note.e4), equals(4)); // Major 3rd
      expect(Note.c4.intervalTo(Note.d4), equals(2)); // Major 2nd
    });

    test('assetPath generates correct generic path', () {
      expect(Note.c4.assetPath(), equals('assets/audio/notes/c4.mp3'));
      expect(
        Note.cSharp4.assetPath(),
        equals('assets/audio/notes/c_sharp_4.mp3'),
      );
      expect(Note.a5.assetPath(), equals('assets/audio/notes/a5.mp3'));
      expect(
        Note.fSharp5.assetPath(),
        equals('assets/audio/notes/f_sharp_5.mp3'),
      );
    });

    test('displayName formats correctly', () {
      expect(Note.c4.displayName, equals('C4'));
      expect(Note.cSharp4.displayName, equals('C#4'));
      expect(Note.aSharp5.displayName, equals('A#5'));
    });

    test('fromMidiNumber returns correct note', () {
      expect(NoteExtension.fromMidiNumber(60), equals(Note.c4));
      expect(NoteExtension.fromMidiNumber(69), equals(Note.a4));
      expect(NoteExtension.fromMidiNumber(100), isNull);
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/voice_line.dart';

void main() {
  group('VoiceLine', () {
    test('every value resolves to exactly one speaker via isPiper — a '
        'switch with no default, so an enum addition that forgets to '
        'assign a speaker fails to compile rather than silently '
        'defaulting to one character', () {
      for (final line in VoiceLine.values) {
        // A read is the assertion here: isPiper is a non-nullable bool
        // computed by an exhaustive switch, so this line alone would fail
        // to compile if any value were left unmapped.
        expect(line.isPiper, isA<bool>());
      }
    });

    test('every value resolves to a real, committed mp3 — guards against '
        'a typo in the enum name vs. the file build_voice_lines.py wrote '
        '(the two are independent strings; nothing else catches a '
        'mismatch until the line silently no-ops on a real device)', () {
      for (final line in VoiceLine.values) {
        final file = File(line.assetPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: '${line.assetPath} does not exist on disk',
        );
      }
    });

    test('assetPath is named after the enum value directly, in '
        'assets/audio/voice/', () {
      expect(
        VoiceLine.giveMeHigh45.assetPath,
        'assets/audio/voice/giveMeHigh45.mp3',
      );
    });
  });
}

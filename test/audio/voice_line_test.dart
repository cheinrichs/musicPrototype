import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/voice_line.dart';

void main() {
  group('VoiceLine', () {
    test('every value has a non-empty caption', () {
      for (final line in VoiceLine.values) {
        expect(
          line.captionText,
          isNotEmpty,
          reason: '$line has no caption text',
        );
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

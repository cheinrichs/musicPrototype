import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/mouth_frames.dart';

void main() {
  group('nextMouthFrame', () {
    test('silence is closed; loud is wide; in between is open', () {
      expect(nextMouthFrame(MouthFrame.closed, 0.0), MouthFrame.closed);
      expect(nextMouthFrame(MouthFrame.closed, 0.4), MouthFrame.open);
      expect(nextMouthFrame(MouthFrame.closed, 0.9), MouthFrame.wide);
      expect(nextMouthFrame(MouthFrame.wide, 0.0), MouthFrame.closed);
    });

    test('hovering at a threshold does not flutter — it takes a real move '
        'back across to change frame again', () {
      // Just around the closed/open boundary (opens at 0.20, closes <0.10).
      var frame = MouthFrame.closed;
      final seen = <MouthFrame>[];
      for (final a in [0.16, 0.22, 0.17, 0.21, 0.15, 0.19, 0.14]) {
        frame = nextMouthFrame(frame, a);
        seen.add(frame);
      }
      expect(
        seen.where((f) => f != MouthFrame.open).length,
        1,
        reason: 'only the first sample (0.16, below the opening point) stays '
            'closed; after that it stays open through the wobble: $seen',
      );

      // Just around the open/wide boundary (wide at 0.60, back <0.50).
      frame = MouthFrame.open;
      final seenWide = <MouthFrame>[];
      for (final a in [0.55, 0.62, 0.56, 0.61, 0.53, 0.60, 0.52]) {
        frame = nextMouthFrame(frame, a);
        seenWide.add(frame);
      }
      expect(
        seenWide.where((f) => f != MouthFrame.wide).length,
        1,
        reason: 'stays wide through the wobble once it gets there: $seenWide',
      );
    });

    test('can jump straight from closed to wide and back', () {
      expect(nextMouthFrame(MouthFrame.closed, 1.0), MouthFrame.wide);
      expect(nextMouthFrame(MouthFrame.wide, 0.05), MouthFrame.closed);
    });
  });

  group('Clef mouth frame assets', () {
    /// Reads a PNG's width and height from its IHDR chunk.
    (int, int) pngSize(String path) {
      final Uint8List bytes = File(path).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      return (data.getUint32(16), data.getUint32(20));
    }

    test('every frame is declared in pubspec.yaml — Flutter asset '
        'directories are not recursive, so a new subfolder that is not '
        'listed ships as missing art without any other test noticing', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(r'^\s*-\s+(assets/\S+/)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toSet();
      for (final path in clefMouthFrameAssets) {
        final dir = path.substring(0, path.lastIndexOf('/') + 1);
        expect(declared, contains(dir), reason: '$path needs $dir declared');
      }
    });

    test('all three frames exist and share one size — the registration '
        'invariant tool/slice_mouth_frames.py enforces: swapping frames must '
        'never change the sprite\'s footprint', () {
      final sizes = {for (final p in clefMouthFrameAssets) p: pngSize(p)};
      expect(sizes.length, 3);
      expect(sizes.values.toSet().length, 1, reason: 'sizes: $sizes');
    });
  });
}

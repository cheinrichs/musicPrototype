import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
import 'package:ear_trainer/games/high_low/widgets/mouth_frames.dart';

(int, int) pngSize(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  final arts = {'clef': CharacterArt.clef, 'piper': CharacterArt.piper};

  group('CharacterArt specs', () {
    for (final entry in arts.entries) {
      final art = entry.value;
      final images = [...art.mouthFrames, art.celebration, art.thinking];

      test('${entry.key}: every sheet size matches its file and every region '
          'lies inside it — a re-cut asset must fail here, not quietly '
          'change her size', () {
        for (final i in images) {
          final (w, h) = pngSize(i.asset);
          expect(i.sheet, Size(w.toDouble(), h.toDouble()), reason: i.asset);
          expect(
            (Offset.zero & i.sheet).intersect(i.region),
            i.region,
            reason: i.asset,
          );
        }
      });

      test('${entry.key}: three mouth frames, all declared in pubspec', () {
        expect(art.mouthFrames.length, 3);
        final pubspec = File('pubspec.yaml').readAsStringSync();
        for (final path in art.allAssets) {
          final dir = path.substring(0, path.lastIndexOf('/') + 1);
          expect(pubspec, contains(dir), reason: '$path needs $dir declared');
        }
      });
    }

    test("Piper's images all stand on her speaking frame's feet", () {
      final p = CharacterArt.piper;
      for (final i in [...p.mouthFrames, p.celebration, p.thinking]) {
        expect(i.box.bottom, p.frameSize.height, reason: i.asset);
        expect(i.box.center.dx, closeTo(p.frameSize.width / 2, 0.01));
      }
    });

    group('Clef (H art, 2026-11-20)', () {
      final c = CharacterArt.clef;

      test('every image is a region of the H sheets as supplied — none of '
          'the bronze files', () {
        for (final a in c.allAssets) {
          expect(a, contains('clef_H_'), reason: a);
        }
        expect(c.mouthFrames.map((i) => i.asset).toSet(), {
          'assets/images/characters/clef/clef_H_talk_x3.png',
        });
      });

      test('the talking frames are cut inside SLICE_POINTS.json\'s columns '
          '(740, 1399)', () {
        final r = [for (final f in c.mouthFrames) f.region];
        expect(r[0].right, lessThanOrEqualTo(740));
        expect(r[1].left, greaterThanOrEqualTo(740));
        expect(r[1].right, lessThanOrEqualTo(1399));
        expect(r[2].left, greaterThanOrEqualTo(1399));
      });

      test('the celebrate pose is measured on near-opaque pixels, not its '
          'canvas-wide glow', () {
        expect(c.celebration.region.width, lessThan(1024 * 0.85));
        expect(c.celebration.region.height, lessThan(1536 * 0.95));
      });

      test('HEAD-MATCHED: with the thoughtful body at H, talking is 0.63H '
          'and celebrating 0.81H', () {
        double drawnBody(CharacterImage i, double bodyPx) =>
            i.box.height * bodyPx / i.region.height;
        final thoughtful = drawnBody(c.thinking, 1476);
        expect(
          drawnBody(c.mouthFrames[0], 719) / thoughtful,
          closeTo(0.63, 1e-6),
        );
        expect(
          drawnBody(c.celebration, 1441) / thoughtful,
          closeTo(0.81, 1e-6),
        );
      });

      test("every image's head lands on one spot, so a change of state "
          'never moves her face', () {
        Offset head(CharacterImage i, Offset sheetHead) {
          final k = i.box.width / i.region.width;
          return i.box.topLeft + (sheetHead - i.region.topLeft) * k;
        }

        final heads = [
          head(c.mouthFrames[0], const Offset(434, 413)),
          head(c.mouthFrames[1], const Offset(1083, 413)),
          head(c.mouthFrames[2], const Offset(1749, 413)),
          head(c.celebration, const Offset(543, 783)),
          head(c.thinking, const Offset(522, 797)),
        ];
        for (final h in heads) {
          expect((h - heads[0]).distance, lessThan(0.01));
        }
      });

      test('12% larger than her speaking frame, about her feet', () {
        final f = c.mouthFrames[0].box;
        expect(f.height, closeTo(c.frameSize.height * 1.12 * 723 / 723, 1));
        expect(f.bottom, closeTo(c.frameSize.height, 1));
      });
    });
  });

  group('CharacterSprite', () {
    Future<void> pump(
      WidgetTester tester,
      CharacterPose pose, {
      MouthFrame mouth = MouthFrame.closed,
      CharacterArt? art,
      double height = 200,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CharacterSprite(
            art: art ?? CharacterArt.clef,
            pose: pose,
            mouth: mouth,
            height: height,
          ),
        ),
      ),
    );

    /// Which of the sprite's layers are showing (opacity 1), by layer key.
    Set<String> visible(WidgetTester tester) => {
      for (final p
          in find
              .descendant(
                of: find.byType(CharacterSprite),
                matching: find.byType(Positioned),
              )
              .evaluate())
        if ((find
                        .descendant(
                          of: find.byWidget(p.widget),
                          matching: find.byType(Opacity),
                        )
                        .evaluate()
                        .first
                        .widget
                    as Opacity)
                .opacity ==
            1.0)
          (p.widget.key! as ValueKey<String>).value,
    };

    testWidgets('speaking shows exactly the current mouth frame', (
      tester,
    ) async {
      for (final m in MouthFrame.values) {
        await pump(tester, CharacterPose.speaking, mouth: m);
        expect(visible(tester), {'clef-mouth-${m.index}'});
      }
    });

    testWidgets('celebrating and thinking each show only their own pose', (
      tester,
    ) async {
      await pump(tester, CharacterPose.celebrating);
      expect(visible(tester), {'clef-celebration'});
      await pump(tester, CharacterPose.thinking);
      expect(visible(tester), {'clef-thinking'});
    });

    testWidgets('a pose ignores the mouth: a celebrating character does not '
        'flap', (tester) async {
      await pump(tester, CharacterPose.celebrating, mouth: MouthFrame.wide);
      expect(visible(tester), {'clef-celebration'});
    });

    for (final entry in arts.entries) {
      testWidgets('${entry.key}: every image is drawn where her art places '
          'it, at one scale', (tester) async {
        final art = entry.value;
        await pump(tester, CharacterPose.speaking, art: art, height: 240);
        final scale = 240 / art.frameSize.height;
        final sprite = tester.getRect(find.byType(CharacterSprite));
        final layers = {
          'mouth-0': art.mouthFrames[0],
          'mouth-1': art.mouthFrames[1],
          'mouth-2': art.mouthFrames[2],
          'celebration': art.celebration,
          'thinking': art.thinking,
        };
        for (final MapEntry(:key, :value) in layers.entries) {
          final r = tester.getRect(find.byKey(ValueKey('${art.name}-$key')));
          final want = Rect.fromLTWH(
            sprite.left + value.box.left * scale,
            sprite.top + value.box.top * scale,
            value.box.width * scale,
            value.box.height * scale,
          );
          expect(r.left, closeTo(want.left, 0.01), reason: key);
          expect(r.top, closeTo(want.top, 0.01), reason: key);
          expect(r.size.width, closeTo(want.width, 0.01), reason: key);
          expect(r.size.height, closeTo(want.height, 0.01), reason: key);
        }
      });
    }
  });
}

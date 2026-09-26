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
  const arts = {'clef': CharacterArt.clef, 'piper': CharacterArt.piper};

  group('CharacterArt specs', () {
    for (final entry in arts.entries) {
      test('${entry.key}: every recorded pixel size matches the file — the '
          'sprite scales images by these numbers, so a re-cut asset with '
          'different dimensions must fail here rather than quietly change '
          'the character\'s size', () {
        final art = entry.value;
        for (final f in art.mouthFrames) {
          final (w, h) = pngSize(f);
          expect(Size(w.toDouble(), h.toDouble()), art.frameSize, reason: f);
        }
        final (cw, ch) = pngSize(art.celebration);
        expect(Size(cw.toDouble(), ch.toDouble()), art.celebrationSize);
        final (tw, th) = pngSize(art.thinking);
        expect(Size(tw.toDouble(), th.toDouble()), art.thinkingSize);
      });

      test('${entry.key}: three mouth frames, all declared in pubspec', () {
        final art = entry.value;
        expect(art.mouthFrames.length, 3);
        final pubspec = File('pubspec.yaml').readAsStringSync();
        for (final path in art.allAssets) {
          final dir = path.substring(0, path.lastIndexOf('/') + 1);
          expect(pubspec, contains(dir), reason: '$path needs $dir declared');
        }
      });
    }

    test('poses are close to the mouth frames in size — one common scale per '
        'character means a swap never makes her jump: celebration and '
        'thinking stay within ~5% of the mouth-frame body height', () {
      for (final art in arts.values) {
        for (final s in [art.celebrationSize, art.thinkingSize]) {
          expect(s.height / art.frameSize.height, closeTo(1.0, 0.05));
        }
      }
    });
  });

  group('CharacterSprite', () {
    Future<void> pump(
      WidgetTester tester,
      CharacterPose pose, {
      MouthFrame mouth = MouthFrame.closed,
      CharacterArt art = CharacterArt.clef,
      double height = 200,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CharacterSprite(
            art: art,
            pose: pose,
            mouth: mouth,
            height: height,
          ),
        ),
      ),
    );

    /// Which of the sprite's images are showing (opacity 1), by asset name.
    Set<String> visible(WidgetTester tester) {
      final result = <String>{};
      for (final o
          in find
              .descendant(
                of: find.byType(CharacterSprite),
                matching: find.byType(Opacity),
              )
              .evaluate()) {
        final opacity = (o.widget as Opacity).opacity;
        final image =
            find
                    .descendant(
                      of: find.byWidget(o.widget),
                      matching: find.byType(Image),
                    )
                    .evaluate()
                    .single
                    .widget
                as Image;
        if (opacity == 1.0) {
          result.add((image.image as AssetImage).assetName.split('/').last);
        }
      }
      return result;
    }

    testWidgets('speaking shows exactly the current mouth frame', (
      tester,
    ) async {
      for (final m in MouthFrame.values) {
        await pump(tester, CharacterPose.speaking, mouth: m);
        expect(visible(tester), {'clef_mouth_${m.index}.png'});
      }
    });

    testWidgets('celebrating and thinking each show only their own pose', (
      tester,
    ) async {
      await pump(tester, CharacterPose.celebrating);
      expect(visible(tester), {'clef_celebration.png'});
      await pump(tester, CharacterPose.thinking);
      expect(visible(tester), {'clef_thinking.png'});
    });

    testWidgets('a pose ignores the mouth: a celebrating character does not '
        'flap', (tester) async {
      await pump(tester, CharacterPose.celebrating, mouth: MouthFrame.wide);
      expect(visible(tester), {'clef_celebration.png'});
    });

    for (final entry in arts.entries) {
      testWidgets('${entry.key}: every image is drawn at one shared scale '
          'and sits on one shared ground line', (tester) async {
        final art = entry.value;
        await pump(tester, CharacterPose.speaking, art: art, height: 240);
        final scale = 240 / art.frameSize.height;

        final images = find
            .descendant(
              of: find.byType(CharacterSprite),
              matching: find.byType(Image),
            )
            .evaluate()
            .map((e) => e.widget as Image)
            .toList();
        expect(images.length, 5);
        final bottoms = <double>{};
        for (final img in images) {
          final name = (img.image as AssetImage).assetName;
          final px = name == art.celebration
              ? art.celebrationSize
              : name == art.thinking
              ? art.thinkingSize
              : art.frameSize;
          expect(img.height, closeTo(px.height * scale, 0.01), reason: name);
          expect(img.width, closeTo(px.width * scale, 0.01), reason: name);
        }
        final sprite = tester.getRect(find.byType(CharacterSprite));
        for (final r
            in find
                .descendant(
                  of: find.byType(CharacterSprite),
                  matching: find.byType(Image),
                )
                .evaluate()
                .map((e) => tester.getRect(find.byWidget(e.widget)))) {
          bottoms.add((r.bottom - sprite.bottom).abs().roundToDouble());
        }
        expect(bottoms, {0.0}, reason: 'all images share the sprite\'s bottom');
      });
    }
  });
}

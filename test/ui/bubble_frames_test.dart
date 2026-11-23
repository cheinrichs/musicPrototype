import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/ui/components/answer_bubble.dart';
import 'package:ear_trainer/ui/components/bubble_frames.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Card 231's bubble art: the generated frame boxes must match the PNGs and
/// the manifest's cut points — never even cells.
void main() {
  final manifest =
      jsonDecode(
            File(
              'assets/images/characters/instruments/SLICE_POINTS.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final MapEntry(key: name, value: (asset, size, boxes))
      in bubbleFrames.entries) {
    test('$name: every frame box is re-measured from the PNG, between the '
        'manifest\'s cuts', () async {
      final file = asset.split('/').last;
      final entry = manifest[file] as Map<String, dynamic>;
      final cuts = [
        0,
        ...(entry['slices'] as List).cast<int>(),
        size.width.toInt(),
      ];
      expect(boxes, hasLength(cuts.length - 1));
      final image = (await (await ui.instantiateImageCodec(
        File(asset).readAsBytesSync(),
      )).getNextFrame()).image;
      expect(image.width, size.width);
      expect(image.height, size.height);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);
      for (var i = 0; i < boxes.length; i++) {
        var l = 1 << 30, t = 1 << 30, r = -1, b = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = cuts[i]; x < cuts[i + 1]; x++) {
            if (alpha(x, y) > 8) {
              if (x < l) l = x;
              if (x > r) r = x;
              if (y < t) t = y;
              if (y > b) b = y;
            }
          }
        }
        expect(
          boxes[i],
          Rect.fromLTWH(
            l.toDouble(),
            t.toDouble(),
            (r - l + 1).toDouble(),
            (b - t + 1).toDouble(),
          ),
          reason: '$file frame $i',
        );
      }
    });
  }

  test('the burst is 8 frames and the wiggle 5 (Cooper\'s sheets)', () {
    expect(bubbleFrames['burst']!.$3, hasLength(8));
    expect(bubbleFrames['wiggle']!.$3, hasLength(5));
  });

  test('the game waits for exactly the burst before the instrument flies', () {
    expect(AnswerBubble.burstDuration, HighLowGameState.bubbleBurst);
  });
}

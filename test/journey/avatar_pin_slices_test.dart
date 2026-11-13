import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ear_trainer/journey/journey_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The avatar pins are sliced from one sheet whose avatars are NOT on an
/// even grid. Cooper on the Journey: "a sliver of the neighbouring character
/// is visible at its right edge". These tests read the real file, so they
/// check every one of the sixteen, not one by eye.
void main() {
  late ByteData pixels;
  late int width;

  setUpAll(() async {
    final bytes = File(JourneyArt.pins).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final image = (await codec.getNextFrame()).image;
    width = image.width;
    expect(
      Size(image.width.toDouble(), image.height.toDouble()),
      JourneyArt.pinSheet,
    );
    pixels = (await image.toByteData())!;
  });

  // Visible: above the faint matte noise the sheet carries everywhere.
  bool visible(int x, int y) => pixels.getUint8((y * width + x) * 4 + 3) > 8;

  test('each avatar is where the table says — a re-exported sheet that '
      'moves one fails here', () {
    for (var i = 0; i < 16; i++) {
      final b = JourneyArt.pinBounds[i];
      // Search a margin around the recorded box for the avatar's extent.
      var l = 1 << 30, t = 1 << 30, r = -1, bo = -1;
      final x0 = (b.left - 8).toInt(), x1 = (b.right + 8).toInt();
      final y0 = (b.top - 6).toInt(), y1 = (b.bottom + 6).toInt();
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          // Only this avatar: stay inside its own gutter-bounded box.
          if (!JourneyArt.pinSlice(i).contains(Offset(x + .5, y + .5))) {
            continue;
          }
          if (!visible(x, y)) continue;
          if (x < l) l = x;
          if (x > r) r = x;
          if (y < t) t = y;
          if (y > bo) bo = y;
        }
      }
      expect(
        Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, bo + 1.0),
        b,
        reason: 'avatar $i',
      );
    }
  });

  test('every slice holds its whole avatar and NOTHING visible of any '
      'other — all sixteen', () {
    for (var i = 0; i < 16; i++) {
      final slice = JourneyArt.pinSlice(i);
      final own = JourneyArt.pinBounds[i];
      expect(slice.left, greaterThanOrEqualTo(0));
      expect(slice.top, greaterThanOrEqualTo(0));
      expect(slice.right, lessThanOrEqualTo(JourneyArt.pinSheet.width));
      expect(slice.bottom, lessThanOrEqualTo(JourneyArt.pinSheet.height));
      expect(slice.intersect(own), own, reason: 'avatar $i clipped');
      final stray = <Offset>[];
      for (var y = slice.top.toInt(); y < slice.bottom.toInt(); y++) {
        for (var x = slice.left.toInt(); x < slice.right.toInt(); x++) {
          final p = Offset(x + .5, y + .5);
          if (visible(x, y) && !own.contains(p)) stray.add(p);
        }
      }
      expect(stray, isEmpty, reason: 'avatar $i catches a neighbour');
    }
  });

  test('the slices are one size, and the tip sits at the same height in '
      'each', () {
    for (var i = 0; i < 16; i++) {
      final slice = JourneyArt.pinSlice(i);
      expect(slice.size, JourneyArt.pinCell);
      final tip = (JourneyArt.pinBounds[i].bottom - slice.top) / slice.height;
      expect(tip, closeTo(JourneyArt.pinTip, 1e-9));
    }
  });
}

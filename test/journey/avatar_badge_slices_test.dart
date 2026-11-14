import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ear_trainer/journey/journey_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The round badges (the picker and the setup quiz) are sliced from one
/// sheet that, like the pins, is not an even grid. These read the real
/// file, so all sixteen are checked, not one by eye.
void main() {
  late ByteData pixels;
  late int width;

  setUpAll(() async {
    final bytes = File(JourneyArt.badges).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final image = (await codec.getNextFrame()).image;
    width = image.width;
    expect(
      Size(image.width.toDouble(), image.height.toDouble()),
      JourneyArt.badgeSheet,
    );
    pixels = (await image.toByteData())!;
  });

  int alpha(int x, int y) => pixels.getUint8((y * width + x) * 4 + 3);

  /// The sheet's sixteen cells: the gutters between badges, measured.
  const cols = [(94, 344), (384, 636), (670, 925), (958, 1213)];
  const rows = [(70, 327), (360, 599), (629, 866), (885, 1121)];

  test("each badge's disc centre is where the table says — a re-exported "
      'sheet that moves one fails here', () {
    for (var i = 0; i < 16; i++) {
      final (x0, x1) = cols[i % 4];
      final (y0, y1) = rows[i ~/ 4];
      var l = 1 << 30, r = -1, b = -1;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          if (alpha(x, y) <= 200) continue; // the solid disc, not its glow
          if (x < l) l = x;
          if (x > r) r = x;
          if (y > b) b = y;
        }
      }
      final d = (r + 1 - l).toDouble();
      expect(
        Offset((l + r + 1) / 2, b + 1 - d / 2),
        JourneyArt.badgeCentres[i],
        reason: 'badge $i',
      );
    }
  });

  test('every slice holds its whole disc and NOTHING of any neighbour — all '
      'sixteen', () {
    for (var i = 0; i < 16; i++) {
      final slice = JourneyArt.badgeSlice(i);
      expect(slice.left, greaterThanOrEqualTo(0));
      expect(slice.top, greaterThanOrEqualTo(0));
      expect(slice.right, lessThanOrEqualTo(JourneyArt.badgeSheet.width));
      expect(slice.bottom, lessThanOrEqualTo(JourneyArt.badgeSheet.height));
      final (x0, x1) = cols[i % 4];
      final (y0, y1) = rows[i ~/ 4];
      final own = Rect.fromLTRB(
        x0.toDouble(),
        y0.toDouble(),
        x1.toDouble(),
        y1.toDouble(),
      );
      var stray = 0;
      for (var y = slice.top.toInt(); y < slice.bottom.toInt(); y++) {
        for (var x = slice.left.toInt(); x < slice.right.toInt(); x++) {
          if (alpha(x, y) > 8 && !own.contains(Offset(x + .5, y + .5))) {
            stray++;
          }
        }
      }
      expect(stray, 0, reason: 'badge $i catches a neighbour');
    }
  });
}

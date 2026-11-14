import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
import 'package:ear_trainer/journey/journey_screen.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Piper and Clef on the Journey map (Cooper, 2026-11-14): figures standing
/// IN the painting, walking with the child — not a posed trio.
void main() {
  const devices = {
    'se': (Size(667, 375), EdgeInsets.zero),
    'iphone14': (Size(844, 390), EdgeInsets.only(left: 47, right: 47)),
    'ipad': (Size(1180, 820), EdgeInsets.zero),
  };

  Rect frame(CharacterArt art, Offset feet, double h) {
    final w = art.frameSize.width * h / art.frameSize.height;
    return Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h);
  }

  for (final MapEntry(key: name, value: (size, padding)) in devices.entries) {
    group(name, () {
      final g = JourneyMapGeometry(size, padding);

      test('Piper NEVER overlaps the avatar pin, on any stone', () {
        for (var i = 0; i < 40; i++) {
          final feet = g.piperFeet(i);
          final piper = frame(
            CharacterArt.piper,
            feet,
            g.piperHeightAt(feet.dx),
          );
          expect(
            piper.right,
            lessThanOrEqualTo(g.pinRect(i).left),
            reason: '$i',
          );
        }
      });

      test('Piper fits on screen behind the very first stone', () {
        final feet = g.piperFeet(0);
        final piper = frame(CharacterArt.piper, feet, g.piperHeightAt(feet.dx));
        expect(piper.left, greaterThanOrEqualTo(padding.left));
      });

      test('they obey the path\'s depth as the stones do: each figure '
          'scales with the path where it stands', () {
        for (var i = 0; i < 40; i++) {
          final p = g.piperFeet(i).dx, c = g.clefFeet(i).dx;
          expect(
            g.piperHeightAt(p) / g.piperHeight,
            closeTo(
              g.stoneSizeAt(p) /
                  g.stoneSizeAt(g.stoneX(0)) *
                  g.depthScaleAt(g.stoneX(0)),
              1e-9,
            ),
          );
          expect(
            g.clefHeightAt(c) / g.companionHeight,
            closeTo(g.depthScaleAt(c), 1e-9),
          );
        }
      });

      test('a group walking, not a posed trio: Piper close behind, Clef '
          'well ahead — never equidistant either side of the pin', () {
        for (var i = 0; i < 40; i++) {
          final pin = g.pinRect(i).center.dx;
          final behind = pin - g.piperFeet(i).dx;
          final ahead = g.clefFeet(i).dx - pin;
          expect(behind, greaterThan(0));
          expect(ahead, greaterThan(behind * 1.4), reason: '$i');
        }
      });

      test('Clef stands clear of the resting chest', () {
        for (var i = 0; i < 40; i++) {
          final feet = g.clefFeet(i);
          final clef = frame(CharacterArt.clef, feet, g.clefHeightAt(feet.dx));
          var m = i;
          while ((m + 1) % 5 != 0) {
            m++;
          }
          final chest = g.chestRect(m);
          expect(
            clef.right <= chest.left || clef.left >= chest.right,
            isTrue,
            reason: '$i',
          );
        }
      });
    });
  }
}

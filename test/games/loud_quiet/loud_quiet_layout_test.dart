import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_pulse.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_layout.dart';

void main() {
  const cases = {
    'tight': (Size(667, 375), EdgeInsets.zero),
    'roomy with notch': (Size(844, 390), EdgeInsets.symmetric(horizontal: 47)),
    'iPhone 17': (Size(874, 402), EdgeInsets.symmetric(horizontal: 62)),
    'Pro Max': (Size(932, 430), EdgeInsets.symmetric(horizontal: 59)),
  };
  final grow = max(SpeakingPulse.maxScaleDelta, 0.08);
  final smallest = HighLowInstrument.values
      .map((i) => i.displaySizeScale)
      .reduce(min);

  for (final entry in cases.entries) {
    final (size, insets) = entry.value;
    group('LoudQuietLayout — ${entry.key}', () {
      LoudQuietLayout l() => LoudQuietLayout(size, insets: insets);

      test('THE TOUCH-TARGET FLOOR holds: the smallest instrument is at '
          'least 64 px — that, not looks, is what the dial gives way to', () {
        expect(
          l().instrumentSize * smallest,
          greaterThanOrEqualTo(LoudQuietLayout.minTouchTarget - 0.01),
        );
      });

      test('the dial is as big as fits, never over the approved 92% of the '
          'height, standing on the bottom of the screen — in practice 56-76%: '
          'the touch floor and the slip gap to the quiet slot both outrank '
          'its size (for Cooper to judge)', () {
        final d = l().dialRect;
        expect(d.height, lessThanOrEqualTo(size.height * 0.92 + 0.01));
        expect(d.height, greaterThan(size.height * 0.5));
        expect(d.bottom, closeTo(size.height, 0.01));
      });

      test('every platform is on screen and inside the safe area — the loud '
          'end is pushed right only as far as that allows', () {
        final layout = l();
        for (var i = 0; i < 3; i++) {
          final half = LoudQuietLayout.platformWidths[i] * layout.dialWidth / 2;
          final c = layout.platform(i);
          expect(c.dx + half, lessThanOrEqualTo(size.width - insets.right));
          expect(c.dy, greaterThan(0));
        }
      });

      test(
        'the quiet end is the NEAR side and the loud end the FAR side, '
        'measured from the instruments — the Decide lines ("far side", '
        '"near side") are only true this way round; never mirror the dial',
        () {
          final layout = l();
          final instruments = layout.instrumentBox(1).center;
          final quiet = layout.platform(LoudQuietLayout.quietPlatform);
          final loud = layout.platform(LoudQuietLayout.loudPlatform);
          expect(
            (loud - instruments).distance,
            greaterThan((quiet - instruments).distance),
          );
        },
      );

      test('the needle turns on the hub: its pivot sits on the hub point, '
          'and its reach is about 21% of the face\'s width', () {
        final layout = l();
        final r = layout.needleRect;
        final pivot = Offset(
          r.left + LoudQuietLayout.needlePivot.dx * r.width,
          r.top + LoudQuietLayout.needlePivot.dy * r.height,
        );
        expect((pivot - layout.hubPoint).distance, lessThan(0.01));
        expect(
          (layout.needleTip(0) - layout.hubPoint).distance,
          closeTo(0.21 * layout.dialWidth, 0.01),
        );
        expect(layout.needleTip(0).dy, lessThan(layout.hubPoint.dy));
      });

      test('the needle\'s swing stays on the dial: at either end of its '
          'sweep the tip is inside the face, above the hub', () {
        final layout = l();
        for (final deg in [
          -LoudQuietLayout.sweepDegrees,
          LoudQuietLayout.sweepDegrees,
        ]) {
          final tip = layout.needleTip(deg);
          expect(layout.dialRect.contains(tip), isTrue);
          expect(tip.dy, lessThan(layout.hubPoint.dy));
        }
      });

      test(
        'Piper stands at the left edge, inside the safe area, between half '
        'and three-quarters of the height, cropped at the ankles at most',
        () {
          final layout = l();
          final piper = layout.piperBounds(pulse: grow);
          expect(piper.left, greaterThanOrEqualTo(insets.left - 0.5));
          expect(layout.piperHeight, greaterThanOrEqualTo(size.height * 0.5));
          expect(layout.piperHeight, lessThanOrEqualTo(size.height * 0.75));
          expect(
            layout.piperFeetY - size.height,
            lessThan(layout.piperHeight * 0.1),
          );
        },
      );

      test('the instruments stand between Piper and the dial: clear of each '
          'other, of both characters, and of the dial\'s arc', () {
        final layout = l();
        final a = layout.instrumentBox(0);
        final b = layout.instrumentBox(1);
        expect(b.left, greaterThanOrEqualTo(a.right - 0.5));
        for (final box in [a, b]) {
          expect(box.left, greaterThanOrEqualTo(layout.piperRight));
          expect(box.overlaps(layout.clefBounds(pulse: grow)), isFalse);
          expect(
            box.right,
            lessThanOrEqualTo(layout.dialRect.left + 0.2 * layout.dialWidth),
          );
        }
      });

      test('Clef sits on the middle platform, which two instruments never '
          'use, fully on screen', () {
        final layout = l();
        expect(layout.clefPerch, layout.platform(LoudQuietLayout.clefPlatform));
        final clef = layout.clefBounds(pulse: grow);
        expect(clef.top, greaterThan(0));
        for (final loud in [true, false]) {
          expect(
            layout.slotPlatformFor(loud: loud),
            isNot(LoudQuietLayout.clefPlatform),
          );
        }
      });

      test('NO CHARACTER OVERLAPS A DROP SLOT', () {
        final layout = l();
        for (final loud in [true, false]) {
          final slot = layout.slotRect(layout.slotPlatformFor(loud: loud));
          expect(slot.overlaps(layout.piperBounds(pulse: grow)), isFalse);
          expect(slot.overlaps(layout.clefBounds(pulse: grow)), isFalse);
        }
      });

      test('A TAP NEVER ANSWERS: every slot is more than a finger\'s slip from '
          'every instrument', () {
        final layout = l();
        for (var i = 0; i < 2; i++) {
          for (final loud in [true, false]) {
            final slot = layout.slotRect(layout.slotPlatformFor(loud: loud));
            expect(
              slot.left - layout.instrumentBox(i).right,
              greaterThan(48 - 0.01),
            );
          }
        }
      });

      test('the caption\'s meadow ends at the dial', () {
        final layout = l();
        expect(layout.meadowRight, layout.dialRect.left);
      });

      test(
        'the arrow sits between the last instrument and the dial\'s arc',
        () {
          final layout = l();
          expect(
            layout.arrowCentre.dx,
            greaterThan(layout.instrumentBox(1).right),
          );
        },
      );
    });
  }

  test('the dial sizes measured on real phones, for the record', () {
    for (final entry in cases.entries) {
      final (size, insets) = entry.value;
      final l = LoudQuietLayout(size, insets: insets);
      // ignore: avoid_print
      print(
        '${entry.key}: dial ${(l.dialHeight / size.height).toStringAsFixed(2)}'
        ' H, Piper ${(l.piperHeight / size.height).toStringAsFixed(2)} H, '
        'instruments ${l.instrumentSize.toStringAsFixed(0)} px',
      );
    }
  });
}

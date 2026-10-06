import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/scene_layout.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_pulse.dart';

void main() {
  // Real landscape phones: an SE-sized screen, an iPhone 14 (notch insets),
  // iPhone 17 and a Pro Max.
  const cases = {
    'tight': (Size(667, 375), EdgeInsets.zero),
    'roomy with notch': (Size(844, 390), EdgeInsets.symmetric(horizontal: 47)),
    'iPhone 17': (Size(874, 402), EdgeInsets.symmetric(horizontal: 62)),
    'Pro Max': (Size(932, 430), EdgeInsets.symmetric(horizontal: 59)),
  };

  // The most a character ever grows: the speaking pulse, or the celebration
  // pose's own scale-up, whichever is larger.
  final grow = max(SpeakingPulse.maxScaleDelta, 0.08);

  for (final entry in cases.entries) {
    final (size, insets) = entry.value;
    group('SceneLayout — ${entry.key}', () {
      SceneLayout two() => SceneLayout(size, insets: insets, noteCount: 2);
      SceneLayout three() => SceneLayout(size, insets: insets, noteCount: 3);

      Rect instrumentBox(SceneLayout l, int i) => Rect.fromCenter(
        center: Offset(
          l.stumpAnchorX(i),
          l.stumpFeet(i).dy - l.instrumentSize / 2,
        ),
        width: l.instrumentSize,
        height: l.instrumentSize,
      );

      test('the tree is full screen height with a quarter of its width off '
          'the right edge (Trello card 187 — smaller was tested and does '
          'not work: the platforms become too small to hit)', () {
        final l = two();
        expect(l.treeRect.top, 0);
        expect(l.treeRect.height, size.height);
        expect(
          l.treeRect.right - size.width,
          closeTo(l.treeWidth * 0.25, 0.001),
        );
      });

      test('every platform face is on screen and inside the safe area', () {
        final l = two();
        for (var i = 0; i < 3; i++) {
          final c = l.platform(i);
          final half = l.platformFaceWidth(i) / 2;
          expect(c.dx + half, lessThanOrEqualTo(size.width - insets.right));
          expect(c.dx - half, greaterThan(insets.left));
          expect(c.dy, inInclusiveRange(0, size.height));
        }
        // Top to bottom, as the art has them.
        expect(l.platform(0).dy, lessThan(l.platform(1).dy));
        expect(l.platform(1).dy, lessThan(l.platform(2).dy));
      });

      test('Clef sits on the branch, fully on screen even at the peak of the '
          'speaking pulse, and covers no platform', () {
        final l = two();
        final clef = l.clefBounds(pulse: grow);
        expect(clef.top, greaterThan(0));
        expect(clef.left, greaterThanOrEqualTo(insets.left));
        expect(clef.right, lessThan(l.platformColumnLeftX));
        expect(l.clefPerch.dx, greaterThan(l.treeRect.left));
      });

      test('Piper stands at the LEFT edge, inside the safe area, at a '
          'clearly larger scale than Clef, with only a sliver of her own '
          'height (ankles at most) below the frame', () {
        final l = two();
        final piper = l.piperBounds(pulse: grow);
        expect(piper.left, greaterThanOrEqualTo(insets.left));
        expect(piper.right, lessThan(size.width * 0.35));
        expect(l.piperHeight, greaterThan(l.characterHeight * 1.5));
        expect(l.piperFeetY, greaterThan(size.height));
        expect(l.piperFeetY - size.height, lessThan(l.piperHeight * 0.1));
      });

      test('the instruments stand between Piper and the tree: clear of '
          'each other, of both characters, and of the platform column', () {
        final l = two();
        final a = instrumentBox(l, 0);
        final b = instrumentBox(l, 1);
        expect(
          b.left,
          greaterThanOrEqualTo(a.right - 0.5),
          reason: 'boxes may touch, not overlap',
        );
        final piper = l.piperBounds(pulse: grow);
        final clef = l.clefBounds(pulse: grow);
        for (final box in [a, b]) {
          expect(box.left, greaterThanOrEqualTo(piper.right));
          expect(box.right, lessThanOrEqualTo(l.platformColumnLeftX));
          expect(box.overlaps(clef), isFalse);
        }
      });

      test('THE TOUCH-TARGET FLOOR: the smallest instrument stays big '
          'enough for a small finger — that, not looks, is what limits how '
          'far back the stumps go (Trello card 187)', () {
        final l = two();
        final smallest = HighLowInstrument.values
            .map((i) => i.displaySizeScale)
            .reduce(min);
        expect(
          l.instrumentSize * smallest,
          greaterThanOrEqualTo(SceneLayout.minTouchTarget),
        );
      });

      test('the stumps sit back in space: higher up and smaller than '
          'before the layout pass (ground line was 0.84 of the height, '
          'instruments half of it)', () {
        final l = two();
        expect(size.height - l.groundY, lessThan(size.height * 0.84));
        expect(l.instrumentSize, lessThan(size.height * 0.5));
      });

      test('one floor: the stumps\' ground line agrees with the tree\'s '
          'base — its bottom platform sits just above it', () {
        final l = two();
        final groundLine = size.height - l.groundY;
        expect(
          (l.platform(2).dy - groundLine).abs(),
          lessThan(size.height * 0.05),
        );
      });

      test('placed instruments fit the gap between platforms', () {
        final l = two();
        expect(
          l.placedSize,
          lessThanOrEqualTo(l.platform(1).dy - l.platform(0).dy),
        );
        expect(
          l.placedSize,
          lessThanOrEqualTo(l.platform(2).dy - l.platform(1).dy),
        );
      });

      group('the tree slot (the drop target, not a character)', () {
        test('high is the top platform, low the bottom one — the widest '
            'contrast three platforms allow, now that Clef is off them', () {
          final l = two();
          expect(l.slotPlatformFor(isPiperTarget: false), 0);
          expect(l.slotPlatformFor(isPiperTarget: true), 2);
        });

        test('NO CHARACTER OVERLAPS A DROP SLOT — Piper\'s tail used to cover '
            'half the bottom one; verified, not assumed (Trello card 187)', () {
          final l = two();
          for (final i in [0, 1, 2]) {
            final slot = l.slotRect(i);
            expect(
              slot.overlaps(l.piperBounds(pulse: grow)),
              isFalse,
              reason: 'Piper over platform $i',
            );
            expect(
              slot.overlaps(l.clefBounds(pulse: grow)),
              isFalse,
              reason: 'Clef over platform $i',
            );
          }
        });

        test('the slot footprint fits its platform\'s face', () {
          final l = two();
          for (var i = 0; i < 3; i++) {
            expect(l.slotSize.width, lessThanOrEqualTo(l.platformFaceWidth(i)));
          }
        });
      });

      test('the caption\'s meadow ends at the tree, before any platform', () {
        final l = two();
        expect(l.meadowRight, l.treeRect.left);
        expect(l.meadowRight, lessThan(l.platformColumnLeftX));
      });

      test('the earned arrow sits between the last instrument and the '
          'platform column', () {
        final l = two();
        expect(l.arrowCentre.dx - 36, greaterThan(l.instrumentsRight - 40));
        expect(l.arrowCentre.dx + 36, lessThan(l.platformColumnLeftX));
      });

      test('Listen Again sits below the stumps and on screen', () {
        final l = two();
        expect(l.listenAgainCenter.dy, greaterThan(size.height - l.groundY));
        expect(l.listenAgainCenter.dy + 20, lessThanOrEqualTo(size.height));
      });

      test('three instruments are the same composition with one more: same '
          'tree, same characters, same floor, all clear of each other and '
          'of the tree, and fixed for the round (no reflow)', () {
        final a = two();
        final b = three();
        expect(b.treeRect, a.treeRect);
        expect(b.clefPerch, a.clefPerch);
        expect(b.piperFeetY, a.piperFeetY);
        expect(b.groundY, a.groundY);
        final xs = [for (var i = 0; i < 3; i++) b.stumpAnchorX(i)];
        expect(xs, orderedEquals([...xs]..sort()));
        for (var i = 0; i < 2; i++) {
          expect(
            instrumentBox(b, i + 1).left,
            greaterThanOrEqualTo(instrumentBox(b, i).right - 0.5),
          );
        }
        expect(b.instrumentsRight, lessThanOrEqualTo(b.platformColumnLeftX));
      });
    });
  }
}

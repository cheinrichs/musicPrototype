import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/scene_layout.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_layout.dart';
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

      test('CLEF\'S SEAT FOLLOWS THE INSTRUMENT COUNT (Trello card 188): with '
          'two he sits on the top platform, taking it — "this one is taken", '
          'with no UI — and is fully on screen and inside the safe area even '
          'at the peak of the speaking pulse', () {
        final l = two();
        expect(l.clefOnBranch, isFalse);
        expect(l.clefPerch, l.platform(0));
        expect(l.freePlatforms, [1, 2]);
        final clef = l.clefBounds(pulse: grow);
        expect(clef.top, greaterThan(0));
        expect(clef.right, lessThanOrEqualTo(size.width - insets.right));
      });

      test('with three he moves to the branch, freeing all three platforms, '
          'and covers none of them', () {
        final l = three();
        expect(l.clefOnBranch, isTrue);
        expect(l.freePlatforms, [0, 1, 2]);
        final clef = l.clefBounds(pulse: grow);
        expect(clef.top, greaterThan(0));
        expect(clef.left, greaterThanOrEqualTo(insets.left));
        expect(clef.right, lessThan(l.platformColumnLeftX));
        expect(l.clefPerch.dx, greaterThan(l.treeRect.left));
      });

      test('either way Clef stays high: above every free platform', () {
        for (final l in [two(), three()]) {
          for (final p in l.freePlatforms) {
            expect(l.clefPerch.dy, lessThan(l.platform(p).dy));
          }
        }
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
        test('two instruments: Clef has the top, so HIGH is the middle '
            'platform and LOW the bottom — relative, the higher of the two '
            'available is up (Trello card 188)', () {
          final l = two();
          expect(l.slotPlatformFor(isPiperTarget: false), 1);
          expect(l.slotPlatformFor(isPiperTarget: true), 2);
        });

        test('three instruments: all three free, so high is the top and low '
            'the bottom', () {
          final l = three();
          expect(l.slotPlatformFor(isPiperTarget: false), 0);
          expect(l.slotPlatformFor(isPiperTarget: true), 2);
        });

        test('a slot is never the platform Clef is sitting on', () {
          for (final l in [two(), three()]) {
            for (final isPiperTarget in [true, false]) {
              expect(
                l.freePlatforms,
                contains(l.slotPlatformFor(isPiperTarget: isPiperTarget)),
              );
            }
          }
        });

        test('NO CHARACTER OVERLAPS A DROP SLOT — Piper\'s tail used to cover '
            'half the bottom one; verified, not assumed (Trello card 187), '
            'for every free platform, with Clef in either seat', () {
          for (final l in [two(), three()]) {
            for (final i in l.freePlatforms) {
              final slot = l.slotRect(i);
              expect(
                slot.overlaps(l.piperBounds(pulse: grow)),
                isFalse,
                reason: 'Piper over platform $i (${l.noteCount} instruments)',
              );
              expect(
                slot.overlaps(l.clefBounds(pulse: grow)),
                isFalse,
                reason: 'Clef over platform $i (${l.noteCount} instruments)',
              );
            }
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
          'tree, same Piper, same floor — only Clef moves, up to the '
          'branch — all clear of each other and of the tree, and fixed for '
          'the round (no reflow)', () {
        final a = two();
        final b = three();
        expect(b.treeRect, a.treeRect);
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

      group('the ordering screen is the same tree (Trello card 188)', () {
        test('its slots are the free platforms, highest first: the two under '
            'Clef with two notes, all three with three', () {
          final o2 = OrderingLayout(size, insets: insets, noteCount: 2);
          expect(o2.slotCentre(0), o2.platform(1));
          expect(o2.slotCentre(1), o2.platform(2));
          expect(o2.clefFeet, o2.platform(0));
          final o3 = OrderingLayout(size, insets: insets, noteCount: 3);
          for (var s = 0; s < 3; s++) {
            expect(o3.slotCentre(s), o3.platform(s));
          }
          expect(o3.clefOnBranch, isTrue);
        });

        test('with no Piper its instruments start at the left edge, clear of '
            'each other and of the platform column, and above the touch '
            'floor', () {
          for (final n in [2, 3]) {
            final o = OrderingLayout(size, insets: insets, noteCount: n);
            expect(
              o.stumpAnchorX(0) - o.instrumentSize / 2,
              greaterThanOrEqualTo(insets.left),
            );
            expect(
              o.instrumentsRight,
              lessThanOrEqualTo(o.platformColumnLeftX),
            );
            final smallest = HighLowInstrument.values
                .map((i) => i.displaySizeScale)
                .reduce(min);
            expect(
              o.instrumentSize * smallest,
              greaterThanOrEqualTo(SceneLayout.minTouchTarget),
            );
          }
        });
      });
    });
  }
}

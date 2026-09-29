import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/scene_layout.dart';
import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
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

  for (final entry in cases.entries) {
    final (size, insets) = entry.value;
    group('SceneLayout — ${entry.key}', () {
      SceneLayout two() => SceneLayout(size, insets: insets, noteCount: 2);
      SceneLayout three() => SceneLayout(
        size,
        insets: insets,
        noteCount: 3,
        instrumentFraction: 0.36,
      );

      test(
        'the tree stands in the right of the frame, inside the safe area',
        () {
          final l = two();
          expect(l.clefPerch.dx, greaterThan(size.width * 0.65));
          final half = SceneLayout.platformWidth * l.treeWidth / 2;
          expect(
            l.clefPerch.dx + half,
            lessThanOrEqualTo(size.width - insets.right),
          );
        },
      );

      test('Clef stays fully on screen, even at the peak of the speaking '
          'pulse', () {
        final l = two();
        final w = l.spriteWidth(CharacterArt.clef, l.characterHeight);
        final grown = w * (1 + SpeakingPulse.maxScaleDelta);
        expect(
          l.clefPerch.dx + grown / 2,
          lessThanOrEqualTo(size.width - insets.right),
        );
        expect(l.clefPerch.dx - grown / 2, greaterThanOrEqualTo(insets.left));
        expect(l.clefPerch.dy - l.characterHeight, greaterThan(0));
      });

      test('Piper stands beside the tree, at a clearly larger scale than Clef '
          '(2026-09-27: she used to perch on a lower platform and rendered '
          'tiny against the tree\'s perspective — Cooper: "have her standing '
          'beside the tree ... at her proper scale")', () {
        final l = two();
        expect(l.piperHeight, greaterThan(l.characterHeight * 1.5));
      });

      test(
        'Piper\'s feet are anchored to the bottom of the SCREEN, not to a '
        'tree platform (2026-09-28, superseding the platform-anchored '
        'version above — Cooper, on device: "Piper far too low... we '
        'should only cut off her feet at most") — only a small, deliberate '
        'sliver of her own height overflows the true bottom edge',
        () {
          final l = two();
          expect(l.piperFeetY, greaterThan(size.height));
          expect(l.piperFeetY - size.height, lessThan(l.piperHeight * 0.1));
        },
      );

      test('Piper is anchored to the right edge of the frame, inside the '
          'device\'s own safe-area inset', () {
        final l = two();
        expect(l.piperRightInset, greaterThanOrEqualTo(insets.right));
      });

      test('INSTRUMENTS KEEP THEIR PROMINENCE: at A0/A1 the instruments are '
          'the whole activity, so the tree must not squeeze them — they stay '
          'at half the screen height, and far bigger than Clef', () {
        final l = two();
        expect(l.instrumentSize, greaterThanOrEqualTo(size.height * 0.5));
        expect(l.instrumentSize, greaterThan(l.characterHeight * 1.8));
      });

      test('two instruments are clear of each other, of the notch, and of '
          'the tree platforms', () {
        final l = two();
        final half = l.instrumentSize / 2;
        expect(l.stumpAnchorX(0) - half, greaterThanOrEqualTo(insets.left));
        expect(
          l.stumpAnchorX(1) - half,
          greaterThanOrEqualTo(l.stumpAnchorX(0) + half - 1),
          reason: 'boxes may touch, not overlap',
        );
        final faceLeft =
            l.clefPerch.dx - SceneLayout.platformWidth * l.treeWidth / 2;
        expect(l.instrumentsRight, lessThan(faceLeft));
      });

      test('the earned arrow has a free column between the last instrument '
          'and the tree platforms', () {
        final l = two();
        final faceLeft =
            l.clefPerch.dx - SceneLayout.platformWidth * l.treeWidth / 2;
        expect(l.arrowCentre.dx - 36, greaterThan(l.instrumentsRight - 40));
        expect(l.arrowCentre.dx + 36, lessThan(faceLeft));
      });

      test('three instruments are the same composition with one more: '
          'distinct homes, all left of the tree, and the layout is fixed '
          'for the whole round (it cannot reflow when one is picked up)', () {
        final l = three();
        final xs = [for (var i = 0; i < 3; i++) l.stumpAnchorX(i)];
        expect(xs.toSet().length, 3);
        expect(xs, orderedEquals([...xs]..sort()));
        final faceLeft =
            l.clefPerch.dx - SceneLayout.platformWidth * l.treeWidth / 2;
        expect(l.instrumentsRight, lessThan(faceLeft));
        expect(three().stumpFeet(1), l.stumpFeet(1));
      });

      test('a two-instrument scene is the three-instrument scene minus one: '
          'same tree, same perches, same ground line', () {
        final a = SceneLayout(
          size,
          insets: insets,
          noteCount: 2,
          instrumentFraction: 0.36,
        );
        final b = three();
        expect(a.treeRect, b.treeRect);
        expect(a.clefPerch, b.clefPerch);
        expect(a.piperFeetY, b.piperFeetY);
        // The first stump is in the same place; how far the others are
        // spaced may tighten on a narrow screen (a third instrument needs
        // room), but they only ever get closer, never rearranged.
        expect(a.stumpFeet(0), b.stumpFeet(0));
        expect(a.stumpFeet(1).dx, greaterThanOrEqualTo(b.stumpFeet(1).dx));
      });

      test('the bottom platform sits near the stumps\' ground line — one '
          'floor — and every platform is on screen', () {
        final l = two();
        final groundLine = size.height - l.groundY;
        expect(
          (l.platform(3).dy - groundLine).abs(),
          lessThan(size.height * 0.05),
        );
        expect(l.platform(3).dy, lessThan(size.height));
      });

      test('placed instruments fit the gap between platforms', () {
        final l = two();
        expect(
          l.placedSize,
          lessThanOrEqualTo(l.platform(2).dy - l.platform(1).dy),
        );
      });

      group('the tree slot (2026-09-27: the drop target, not a character)', () {
        test('the high slot sits right under Clef; the low slot sits at '
            'the tree\'s base — the widest top/bottom contrast the three '
            'free platforms allow', () {
          final l = two();
          expect(l.slotPlatformFor(isPiperTarget: false), 1);
          expect(l.slotPlatformFor(isPiperTarget: true), 3);
          expect(
            l.slotPlatformFor(isPiperTarget: false),
            lessThan(l.slotPlatformFor(isPiperTarget: true)),
          );
        });

        test('exactly one slot platform per round, never Clef\'s own '
            '(platform 0) — one slot for two instruments, not two, or it '
            'quietly becomes an ordering task', () {
          final l = two();
          for (final isPiperTarget in [true, false]) {
            expect(l.slotPlatformFor(isPiperTarget: isPiperTarget), isNot(0));
          }
        });

        test('the slot footprint fits its platform\'s face', () {
          final l = two();
          expect(l.slotSize.width, lessThanOrEqualTo(l.treeWidth));
          expect(l.slotSize.height, greaterThan(0));
        });
      });
    });
  }
}

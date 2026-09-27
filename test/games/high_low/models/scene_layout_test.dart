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

      test('Clef stands ABOVE Piper, on the same tree — Clef owns high, Piper '
          'owns low, so the scene restates the concept every round. An '
          'invariant, not an accident of the sketch', () {
        final l = two();
        expect(l.clefPerch.dy, lessThan(l.piperPerch.dy));
        expect(l.clefPerch.dx, l.piperPerch.dx);
        expect(
          l.piperPerch.dy - l.clefPerch.dy,
          greaterThan(size.height * 0.3),
          reason: 'clearly high and clearly low, not adjacent branches',
        );
      });

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

      test('both characters are the same size and stay fully on screen, '
          'even at the peak of the speaking pulse', () {
        final l = two();
        for (final art in [CharacterArt.clef, CharacterArt.piper]) {
          for (final perch in [l.clefPerch, l.piperPerch]) {
            final w = l.spriteWidth(art, l.characterHeight);
            final grown = w * (1 + SpeakingPulse.maxScaleDelta);
            expect(
              perch.dx + grown / 2,
              lessThanOrEqualTo(size.width - insets.right),
            );
            expect(perch.dx - grown / 2, greaterThanOrEqualTo(insets.left));
          }
        }
        expect(l.clefPerch.dy - l.characterHeight, greaterThan(0));
      });

      test('INSTRUMENTS KEEP THEIR PROMINENCE: at A0/A1 the instruments are '
          'the whole activity, so the tree must not squeeze them — they stay '
          'at half the screen height, and far bigger than the characters', () {
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
        expect(a.piperPerch, b.piperPerch);
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
          (l.piperPerch.dy - groundLine).abs(),
          lessThan(size.height * 0.05),
        );
        expect(l.piperPerch.dy, lessThan(size.height));
      });

      test('placed instruments fit the gap between platforms', () {
        final l = two();
        expect(
          l.placedSize,
          lessThanOrEqualTo(l.platform(2).dy - l.platform(1).dy),
        );
      });
    });
  }
}

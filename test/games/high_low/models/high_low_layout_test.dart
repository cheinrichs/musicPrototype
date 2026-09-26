import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_layout.dart';
import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_pulse.dart';

void main() {
  const tight = Size(667, 375);
  const roomy = Size(844, 390);
  // An iPhone 14 in landscape reserves ~47px each side for the notch and
  // rounded corners (the bug: Clef's right hand ran off the screen).
  const notched = EdgeInsets.symmetric(horizontal: 47);
  const cases = {
    'tight': (tight, EdgeInsets.zero),
    'roomy': (roomy, EdgeInsets.zero),
    'roomy with notch': (roomy, notched),
  };

  for (final entry in cases.entries) {
    final (size, insets) = entry.value;
    group('HighLowLayout — ${entry.key}', () {
      HighLowLayout layout({bool target = true}) =>
          HighLowLayout(size, insets: insets, hasTarget: target);

      test('prominence follows the TASK: the character the child is asked to '
          'drag to is always drawn larger than the one standing by', () {
        final l = layout();
        expect(l.targetHeight, greaterThan(l.waitingHeight));
        expect(
          l.waitingHeight / l.targetHeight,
          lessThan(0.85),
          reason: 'clearly smaller, not a marginal difference',
        );
      });

      test('with no task character (A0 just narrates) both are the same '
          'size — nobody outranks anybody', () {
        final l = layout(target: false);
        expect(l.waitingHeight, l.waitingHeightNoTarget);
        // both sides use one size; nothing is bigger than the other
        expect(l.waitingHeightNoTarget, lessThan(l.targetHeight));
      });

      test('a character at the edge stays fully on screen, even at the peak '
          'of the speaking pulse — including a wider art than the resting '
          'sprite', () {
        final l = layout();
        for (final art in [CharacterArt.clef, CharacterArt.piper]) {
          final w = l.spriteWidth(art, l.waitingHeight);
          final grown = w * (1 + SpeakingPulse.maxScaleDelta);
          final leftEdge = l.leftEdgeX + (w - grown) / 2;
          final rightEdge = l.rightEdgeX - w + (w - grown) / 2 + grown;
          expect(leftEdge, greaterThanOrEqualTo(insets.left));
          expect(rightEdge, lessThanOrEqualTo(size.width - insets.right));
        }
      });

      test('edge characters stand on the same ground line as the stumps, '
          'above the bottom control row, so neither covers the other', () {
        final l = layout();
        expect(l.characterLift, l.groundY);
        expect(l.groundY, greaterThanOrEqualTo(l.controlRowHeight));
      });

      test('nothing overlaps: the edge characters and the centred one all '
          'clear the instruments', () {
        final l = layout();
        final instrumentLeft = l.instrumentAnchorX(0) - l.instrumentSize / 2;
        final instrumentRight = l.instrumentAnchorX(1) + l.instrumentSize / 2;
        for (final art in [CharacterArt.clef, CharacterArt.piper]) {
          final w = l.spriteWidth(art, l.waitingHeight);
          expect(l.leftEdgeX + w, lessThanOrEqualTo(instrumentLeft));
          expect(l.rightEdgeX - w, greaterThanOrEqualTo(instrumentRight));
          // The centred target may brush the instruments' square boxes by a
          // little (an instrument's art is narrower than its box, except the
          // piano), but never by more than a tenth of a box.
          final cw = l.spriteWidth(art, l.targetHeight);
          final slack = l.instrumentSize * 0.10;
          expect(
            size.width / 2 - cw / 2,
            greaterThan(l.instrumentAnchorX(0) + l.instrumentSize / 2 - slack),
          );
          expect(
            size.width / 2 + cw / 2,
            lessThan(l.instrumentAnchorX(1) - l.instrumentSize / 2 + slack),
          );
        }
      });

      test('instruments are levelled: every instrument stands on the one '
          'ground line, so all their tops share a height', () {
        final l = layout();
        expect(l.instrumentTop(0), l.instrumentTop(1));
      });
    });
  }

  test('a float lifts an instrument off its stump without moving the '
      'stump: bells hang above it', () {
    final l = HighLowLayout(roomy, insets: EdgeInsets.zero, hasTarget: true);
    expect(l.instrumentFeetLift(size: 100, floatFraction: 0.1), 10);
    expect(l.instrumentFeetLift(size: 100, floatFraction: 0), 0);
  });
}

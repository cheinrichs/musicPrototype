import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/scene_layout.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_layout.dart';

void main() {
  const tight = Size(667, 375);
  const roomy = Size(844, 390);

  group('OrderingLayout — the same tree as High vs Low (Trello card 188)', () {
    test('three notes: Clef is on the branch and the slots are all three '
        'platforms, top to bottom, measured off the art at 0.444 / 0.595 / '
        '0.739 of its height', () {
      final layout = OrderingLayout(roomy, noteCount: 3);
      final r = layout.treeRect;
      expect(layout.clefOnBranch, isTrue);
      for (final (slot, y) in [(0, 0.444), (1, 0.595), (2, 0.739)]) {
        expect(layout.slotCentre(slot).dy, closeTo(r.top + y * r.height, 0.5));
      }
      expect(layout.clefFeet.dy, lessThan(layout.slotCentre(0).dy));
    });

    test('two notes: Clef sits on the top platform, taking it, and the two '
        'slots are the platforms below him — the order still reads down from '
        'Clef', () {
      final two = OrderingLayout(roomy, noteCount: 2);
      final three = OrderingLayout(roomy, noteCount: 3);
      expect(two.clefFeet, two.platform(0));
      expect(two.slotCentre(0), three.slotCentre(1));
      expect(two.slotCentre(1), three.slotCentre(2));
    });

    for (final entry in {'tight': tight, 'roomy': roomy}.entries) {
      test('${entry.key}: Clef\'s head is on screen in either seat, and every '
          'slot platform is on screen', () {
        for (final n in [2, 3]) {
          final layout = OrderingLayout(entry.value, noteCount: n);
          expect(
            layout.clefFeet.dy - layout.clefHeight,
            greaterThan(0),
            reason: 'Clef\'s head must be on screen ($n notes)',
          );
          for (var s = 0; s < n; s++) {
            final c = layout.slotCentre(s);
            expect(c.dx, lessThan(entry.value.width));
            expect(c.dy, inInclusiveRange(0, entry.value.height));
          }
        }
      });
    }

    test('an instrument standing on a platform is small enough to fit the '
        'gap to the platform above — placed ones must not sit on top of '
        'each other', () {
      final layout = OrderingLayout(roomy, noteCount: 3);
      for (var s = 0; s < 2; s++) {
        final gap = layout.slotCentre(s + 1).dy - layout.slotCentre(s).dy;
        expect(layout.placedSize, lessThanOrEqualTo(gap));
      }
      expect(
        layout.placedSize,
        lessThan(layout.stumpInstrumentSize),
        reason: 'on the tree they are smaller than on their stumps',
      );
    });

    test('each stump has a fixed home for the whole round: where note N '
        'stands never depends on which other notes are placed, so the '
        'layout cannot reflow when one is picked up', () {
      final a = OrderingLayout(roomy, noteCount: 3);
      final b = OrderingLayout(roomy, noteCount: 3);
      for (var n = 0; n < 3; n++) {
        expect(a.stumpFeet(n), b.stumpFeet(n));
      }
      // ...and every stump is distinct and clear of the platforms.
      final xs = [for (var n = 0; n < 3; n++) a.stumpFeet(n).dx];
      expect(xs.toSet().length, 3);
      for (final x in xs) {
        expect(
          x + a.stumpInstrumentSize / 2,
          lessThanOrEqualTo(a.platformColumnLeftX),
          reason: 'stump at $x reaches the platforms',
        );
      }
    });

    test('there is no Piper on this screen, so the instruments start at the '
        'left edge rather than beside her', () {
      final ordering = OrderingLayout(roomy, noteCount: 2);
      final play = SceneLayout(roomy, noteCount: 2);
      expect(ordering.withPiper, isFalse);
      expect(ordering.stumpAnchorX(0), lessThan(play.stumpAnchorX(0)));
    });
  });
}

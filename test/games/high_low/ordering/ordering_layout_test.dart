import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_layout.dart';

void main() {
  const tight = Size(667, 375);
  const roomy = Size(844, 390);

  group('OrderingLayout', () {
    test('slots sit on the tree platforms — measured from the art at '
        '0.369 / 0.558 / 0.735 of its height, Clef on the first at 0.182', () {
      final layout = OrderingLayout(roomy, noteCount: 3);
      final r = layout.treeRect;
      expect(layout.clefFeet.dy, closeTo(r.top + 0.182 * r.height, 0.5));
      expect(layout.slotCentre(0).dy, closeTo(r.top + 0.369 * r.height, 0.5));
      expect(layout.slotCentre(1).dy, closeTo(r.top + 0.558 * r.height, 0.5));
      expect(layout.slotCentre(2).dy, closeTo(r.top + 0.735 * r.height, 0.5));
      // All on one vertical axis through the platforms' faces.
      expect(layout.slotCentre(0).dx, layout.slotCentre(2).dx);
    });

    for (final entry in {'tight': tight, 'roomy': roomy}.entries) {
      test('${entry.key}: Clef clears the header and the bottom slot clears '
          'the footer, so nothing on the tree is covered by a control', () {
        final layout = OrderingLayout(entry.value, noteCount: 3);
        expect(
          layout.clefFeet.dy - layout.clefHeight,
          greaterThan(entry.value.height * 0.20),
          reason: 'Clef\'s head must sit below the header row',
        );
        expect(
          layout.slotCentre(2).dy,
          lessThan(entry.value.height * 0.86),
          reason: 'the bottom platform must sit above the progress dots',
        );
      });

      test('${entry.key}: the tree stays on screen horizontally', () {
        final r = OrderingLayout(entry.value, noteCount: 3).treeRect;
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(entry.value.width));
      });
    }

    test('an instrument standing on a platform is small enough to fit the '
        'gap to the platform above — placed ones must not sit on top of '
        'each other', () {
      final layout = OrderingLayout(roomy, noteCount: 3);
      final gap = layout.slotCentre(1).dy - layout.slotCentre(0).dy;
      expect(layout.placedSize, lessThanOrEqualTo(gap));
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
      // ...and every stump is distinct and clear of the tree.
      final xs = [for (var n = 0; n < 3; n++) a.stumpFeet(n).dx];
      expect(xs.toSet().length, 3);
      for (final x in xs) {
        final halfBox = a.stumpInstrumentSize / 2;
        final overlapsTree =
            x + halfBox > a.treeRect.left + 0.15 * a.treeRect.width &&
            x - halfBox < a.treeRect.right - 0.15 * a.treeRect.width;
        expect(overlapsTree, isFalse, reason: 'stump at $x overlaps the tree');
      }
    });

    test('a two-note round uses the first two stumps of its own layout, and '
        'the same platforms', () {
      final two = OrderingLayout(roomy, noteCount: 2);
      expect(two.stumpFeet(0).dx, lessThan(roomy.width / 2));
      expect(two.stumpFeet(1).dx, greaterThan(roomy.width / 2));
      expect(
        two.slotCentre(0),
        OrderingLayout(roomy, noteCount: 3).slotCentre(0),
      );
    });
  });
}

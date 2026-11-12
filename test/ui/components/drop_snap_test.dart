import 'dart:math' as math;

import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/scene_layout.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_layout.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_layout.dart';
import 'package:ear_trainer/ui/components/drop_snap.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DropSnap', () {
    const slot = Rect.fromLTWH(100, 100, 50, 20);

    test(
      'distance is zero inside a target and to the nearest edge outside',
      () {
        expect(DropSnap.distanceToRect(const Offset(120, 110), slot), 0);
        expect(DropSnap.distanceToRect(const Offset(120, 80), slot), 20);
        expect(DropSnap.distanceToRect(const Offset(170, 110), slot), 20);
        expect(
          DropSnap.distanceToRect(const Offset(153, 124), slot),
          closeTo(5, 1e-9),
        );
      },
    );

    test('resolves to the nearest target, and to none past the radius', () {
      final targets = {0: slot, 1: const Rect.fromLTWH(100, 200, 50, 20)};
      expect(DropSnap.resolve(const Offset(120, 140), targets, 40), 0);
      expect(DropSnap.resolve(const Offset(120, 170), targets, 40), 1);
      expect(DropSnap.resolve(const Offset(120, 160), targets, 40), 0);
      expect(DropSnap.resolve(const Offset(300, 110), targets, 40), isNull);
      expect(DropSnap.nearest(const Offset(300, 110), targets)!.distance, 150);
      expect(DropSnap.resolve(Offset.zero, const {}, 40), isNull);
    });

    test('the radius is more than half the instrument, so covering the '
        "slot's edge with the instrument always counts", () {
      expect(DropSnap.radiusFor(100), greaterThan(50));
    });
  });

  // A pick-up and put-down without really travelling must never land: from
  // where every instrument rests, the nearest slot is further than the
  // accept radius by at least a deliberate movement (card 221). Measured on
  // what's drawn — each instrument's own size and float — on the phones and
  // iPads the app targets.
  group('the accept radius never reaches a resting instrument', () {
    const devices = {
      'iPhone SE': (Size(667, 375), EdgeInsets.zero),
      'iPhone 14': (Size(844, 390), EdgeInsets.symmetric(horizontal: 47)),
      'Pro Max': (Size(932, 430), EdgeInsets.symmetric(horizontal: 59)),
      'iPad mini': (Size(1133, 744), EdgeInsets.zero),
      'iPad': (Size(1180, 820), EdgeInsets.zero),
    };

    // Two drag-start slops: more than a finger wobbling during a tap.
    const travel = 2 * kTouchSlop;

    ({double clearance, double radius}) worst(
      double box,
      Offset feet,
      List<Rect> slots,
    ) {
      var clearance = double.infinity;
      var radius = 0.0;
      for (final i in HighLowInstrument.values) {
        final size = box * i.displaySizeScale;
        final centre = Offset(
          feet.dx,
          feet.dy - size * i.floatFraction - size / 2,
        );
        final d = slots
            .map((s) => DropSnap.distanceToRect(centre, s))
            .reduce(math.min);
        if (d - DropSnap.radiusFor(size) < clearance - radius) {
          clearance = d;
          radius = DropSnap.radiusFor(size);
        }
      }
      return (clearance: clearance, radius: radius);
    }

    for (final MapEntry(key: name, value: (size, insets)) in devices.entries) {
      test('tree, $name', () {
        final l = SceneLayout(size, insets: insets, noteCount: 2);
        final slots = l.freePlatforms.map(l.slotRect).toList();
        for (final side in [0, 1]) {
          final w = worst(l.instrumentSize, l.stumpFeet(side), slots);
          expect(w.clearance - w.radius, greaterThan(travel));
        }
      });

      test('ordering, $name', () {
        for (final n in [2, 3]) {
          final l = OrderingLayout(size, insets: insets, noteCount: n);
          final slots = l.freePlatforms.map(l.slotRect).toList();
          for (var note = 0; note < n; note++) {
            final w = worst(l.stumpInstrumentSize, l.stumpFeet(note), slots);
            expect(w.clearance - w.radius, greaterThan(travel));
          }
        }
      });

      test('dial, $name', () {
        final l = LoudQuietLayout(size, insets: insets);
        final slots = [
          l.slotRect(l.slotPlatformFor(loud: true)),
          l.slotRect(l.slotPlatformFor(loud: false)),
        ];
        for (final side in [0, 1]) {
          final feet = Offset(l.stumpAnchorX(side), size.height - l.groundY);
          final w = worst(l.instrumentSize, feet, slots);
          expect(w.clearance - w.radius, greaterThan(travel));
        }
      });
    }
  });
}

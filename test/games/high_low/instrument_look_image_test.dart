import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/widgets/instrument_look_image.dart';

void main() {
  // The box's bottom is the stump's surface. A wide slice (the xylophone)
  // centred in a square box hung above it and floated over the stump
  // (Cooper, on device, 2026-11-20); it must stand on the box's bottom.
  testWidgets('a wide sheet slice stands on the bottom of its box', (
    tester,
  ) async {
    final look = HighLowInstrument.xylophone.looksFor(2)[0];
    expect(look.region, isNotNull);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.square(
            key: const ValueKey('box'),
            dimension: 200,
            child: InstrumentLookImage(look),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(const ValueKey('box')));
    final art = tester.getRect(find.byType(AspectRatio));
    expect(art.bottom, closeTo(box.bottom, 0.5));
    expect(art.height, lessThan(box.height));
    expect(art.center.dx, closeTo(box.center.dx, 0.5));
  });
}

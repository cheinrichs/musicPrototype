import 'package:ear_trainer/app/art_registry.dart';
import 'package:ear_trainer/journey/journey_travel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Journey travel (Trello 227): Piper walks, Clef hops, the pin arcs, and
/// each sheet plays on its own baselines — no code lift on a character.
void main() {
  const rest = SizedBox.expand(key: ValueKey('rest'));
  const duration = Duration(milliseconds: 1100);

  Future<void> pump(WidgetTester tester, Rect rect, Gait? gait) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Traveller(
                key: const ValueKey('t'),
                rect: rect,
                gait: gait,
                bodyHeight: 100,
                arc: gait == null ? 0.15 : 0,
                duration: duration,
                rest: rest,
              ),
            ],
          ),
        ),
      );

  const from = Rect.fromLTWH(0, 100, 60, 100);
  const to = Rect.fromLTWH(400, 100, 60, 100);

  /// The drawn box of whatever is showing: rest, or a movement frame.
  Rect drawn(WidgetTester tester) {
    final region = find.byType(ImageRegion);
    return region.evaluate().isEmpty
        ? tester.getRect(find.byKey(const ValueKey('rest')))
        : tester.getRect(region);
  }

  int? frameShowing(WidgetTester tester) {
    final region = find.byType(ImageRegion);
    if (region.evaluate().isEmpty) return null;
    final art = tester.widget<ImageRegion>(region).art;
    return (art.region.left / art.region.width).round();
  }

  testWidgets('a new stone starts a trip: frames while travelling, then '
      'the resting pose at the far stone', (tester) async {
    await pump(tester, from, Gait.piperWalk);
    expect(frameShowing(tester), isNull);
    await pump(tester, to, Gait.piperWalk);
    await tester.pump(const Duration(milliseconds: 300));
    expect(frameShowing(tester), isNotNull);
    await tester.pumpAndSettle();
    expect(frameShowing(tester), isNull);
    expect(tester.getRect(find.byKey(const ValueKey('rest'))), to);
  });

  testWidgets('PIPER WALKS: her feet never leave the ground line', (
    tester,
  ) async {
    await pump(tester, from, Gait.piperWalk);
    await pump(tester, to, Gait.piperWalk);
    const k = 100 / 705; // her body height on screen / on the sheet
    for (var ms = 0; ms < 1100; ms += 40) {
      final r = drawn(tester);
      if (frameShowing(tester) != null) {
        // The sheet's foot line (712) sits on the ground (y = 200).
        expect(r.top + 712 * k, closeTo(200, 0.01), reason: '$ms ms');
      }
      await tester.pump(const Duration(milliseconds: 40));
    }
  });

  testWidgets('CLEF HOPS: the lift is her own frame 2, shown mid-hop, in '
      'phase with the travel — one hop per cycle', (tester) async {
    await pump(tester, from, Gait.clefHop);
    await pump(tester, to, Gait.clefHop);
    // Two hops in 1100 ms; the middle of the first is ~275 ms in.
    await tester.pump(const Duration(milliseconds: 275));
    expect(frameShowing(tester), 1, reason: 'airborne mid-hop');
    // The sheet is drawn unshifted: its standing foot line is the ground.
    const k = 100 / 672;
    expect(drawn(tester).top + 715 * k, closeTo(200, 0.01));
    await tester.pump(const Duration(milliseconds: 200));
    expect(frameShowing(tester), 2, reason: 'landing');
  });

  testWidgets('THE PIN ARCS: it rises mid-trip and lands back on its line', (
    tester,
  ) async {
    await pump(tester, from, null);
    await pump(tester, to, null);
    await tester.pump(const Duration(milliseconds: 550));
    final mid = tester.getRect(find.byKey(const ValueKey('rest')));
    expect(mid.top, lessThan(100 - 10), reason: 'up in the air');
    expect(mid.top, greaterThan(100 - 0.15 * 100 - 0.01), reason: 'modest');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('rest'))), to);
  });
}

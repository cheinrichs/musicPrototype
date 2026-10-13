import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/ui/components/continue_bar.dart';

void main() {
  // Real landscape phones, with the notch's side insets and the home
  // indicator's bottom inset where there is one.
  const phones = {
    'SE': (Size(667, 375), EdgeInsets.zero),
    'iPhone 14': (
      Size(844, 390),
      EdgeInsets.only(left: 47, right: 47, bottom: 21),
    ),
    'Pro Max': (
      Size(932, 430),
      EdgeInsets.only(left: 59, right: 59, bottom: 21),
    ),
  };

  group('ContinueBar.rectFor (Trello card 209)', () {
    for (final MapEntry(key: name, value: (size, insets)) in phones.entries) {
      test('$name: centred in the safe area, along the bottom, clear of the '
          'home indicator, and a wide, low, easy target', () {
        final r = ContinueBar.rectFor(size, insets);
        final safeCentre =
            insets.left + (size.width - insets.left - insets.right) / 2;
        expect(r.center.dx, closeTo(safeCentre, 0.001));
        expect(r.left, greaterThanOrEqualTo(insets.left));
        expect(r.right, lessThanOrEqualTo(size.width - insets.right));
        expect(r.bottom, lessThanOrEqualTo(size.height - insets.bottom));
        expect(r.top, greaterThan(size.height * 0.75));
        expect(r.width, greaterThan(r.height * 3));
        expect(r.height, greaterThanOrEqualTo(48));
        // Landscape, not the reference's portrait: well short of the width.
        expect(r.width, lessThan(size.width * 0.5));
      });
    }
  });

  testWidgets('one arrow, no words, and a tap anywhere on the bar counts', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: ContinueBar.height,
            child: ContinueBar(onTap: () => taps++),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    final bar = tester.getRect(find.byType(ContinueBar));
    await tester.tapAt(bar.centerLeft + const Offset(20, 0));
    await tester.tapAt(bar.centerRight - const Offset(20, 0));
    expect(taps, 2);
  });
}

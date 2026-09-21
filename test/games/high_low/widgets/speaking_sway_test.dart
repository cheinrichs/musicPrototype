import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_sway.dart';

void main() {
  Future<void> pumpSway(
    WidgetTester tester, {
    required bool speaking,
    required bool isPiper,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SpeakingSway(
            speaking: speaking,
            isPiper: isPiper,
            child: const SizedBox(width: 40, height: 80),
          ),
        ),
      ),
    );
  }

  double angle(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(SpeakingSway),
        matching: find.byType(Transform),
      ),
    );
    final m = transform.transform;
    return math.atan2(m.entry(1, 0), m.entry(0, 0));
  }

  /// Samples the sway angle every 10ms for [total], after the amplitude
  /// ramp-up has finished, returning (peak |angle|, number of times it
  /// crossed zero).
  Future<({double peak, int crossings})> measure(
    WidgetTester tester,
    Duration total,
  ) async {
    await tester.pump(const Duration(milliseconds: 400));
    var peak = 0.0;
    var crossings = 0;
    // Last non-zero sign, so a sample landing exactly on zero doesn't hide
    // the crossing it belongs to.
    var lastSign = 0.0;
    for (var ms = 0; ms < total.inMilliseconds; ms += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      final a = angle(tester);
      peak = math.max(peak, a.abs());
      if (a != 0) {
        if (lastSign != 0 && a.sign != lastSign) crossings++;
        lastSign = a.sign;
      }
    }
    return (peak: peak, crossings: crossings);
  }

  testWidgets('a character that is not speaking is perfectly still, with '
      'nothing running', (tester) async {
    await pumpSway(tester, speaking: false, isPiper: true);
    await tester.pump(const Duration(seconds: 2));

    expect(angle(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a speaking character sways to both sides — side to side, not '
      'a one-way tilt or an up-down bob', (tester) async {
    await pumpSway(tester, speaking: true, isPiper: true);
    await tester.pump(const Duration(milliseconds: 400));

    final angles = <double>[];
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      angles.add(angle(tester));
    }
    expect(angles.any((a) => a > 0.02), isTrue, reason: 'leans one way');
    expect(angles.any((a) => a < -0.02), isTrue, reason: 'and the other');
  });

  testWidgets(
    'Piper sways slower and wider than Clef, who is quicker and tighter — '
    'the two characters are deliberately opposite in temperament',
    (tester) async {
      await pumpSway(tester, speaking: true, isPiper: true);
      final piper = await measure(tester, const Duration(seconds: 4));

      await tester.pumpWidget(const SizedBox());
      await pumpSway(tester, speaking: true, isPiper: false);
      final clef = await measure(tester, const Duration(seconds: 4));

      expect(
        piper.peak,
        greaterThan(clef.peak),
        reason: 'Piper leans further each way',
      );
      expect(
        clef.crossings,
        greaterThan(piper.crossings),
        reason: 'Clef completes more sways in the same time',
      );
    },
  );

  testWidgets('it eases back to still when the line ends, then stops '
      'running — no snap, and nothing left animating', (tester) async {
    await pumpSway(tester, speaking: true, isPiper: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);

    await pumpSway(tester, speaking: false, isPiper: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(angle(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

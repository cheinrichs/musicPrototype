import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/retry_settle.dart';

void main() {
  testWidgets(
    "a wrong drop's return is one motion: it starts where it was released, "
    'wobbles past the stump as it settles, and ends exactly home when the '
    'fixed duration is up — nothing after it, however long the retry line '
    'runs (Cooper: "a brief wobble ... as it reverts to its placement on '
    'the stump")',
    (tester) async {
      const childKey = ValueKey('settled');
      const from = Offset(200, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RetrySettle(
              from: from,
              child: SizedBox(key: childKey, width: 40, height: 40),
            ),
          ),
        ),
      );
      // Flushes flutter_animate's zero-duration startup timer — see the
      // matching comment on pumpAndFinishIntro in high_low_screen_test.dart.
      await tester.pump();
      await tester.pump(Duration.zero);

      // Home is where it ends up; measure it after the animation, then
      // replay from a fresh mount to sample the journey.
      await tester.pump(
        RetrySettle.duration + const Duration(milliseconds: 50),
      );
      final home = tester.getTopLeft(find.byKey(childKey));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RetrySettle(
              from: from,
              child: SizedBox(key: childKey, width: 40, height: 40),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(Duration.zero);

      final dxs = <double>[];
      const step = Duration(milliseconds: 25);
      var elapsed = Duration.zero;
      while (elapsed < RetrySettle.duration) {
        await tester.pump(step);
        elapsed += step;
        dxs.add(tester.getTopLeft(find.byKey(childKey)).dx - home.dx);
      }

      expect(
        dxs.first,
        greaterThan(from.dx * 0.5),
        reason: 'it starts out at the release point, not already home',
      );
      expect(
        dxs.any((dx) => dx < -1),
        isTrue,
        reason:
            'it overshoots the stump on the way in — that overshoot is the '
            'wobble, as part of the same journey',
      );

      // The journey ends exactly at rest when the duration ends, and
      // nothing (no trailing shake) moves it afterwards.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getTopLeft(find.byKey(childKey)), home);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.getTopLeft(find.byKey(childKey)), home);
    },
  );
}

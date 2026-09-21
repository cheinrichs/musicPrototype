import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/retry_shake.dart';

void main() {
  testWidgets(
    'shakes for its fixed duration, then stops and rests exactly where it '
    'started — however long it stays mounted, so its length never depends '
    'on how long the retry voice line runs (Trello: retry shake too long)',
    (tester) async {
      const childKey = ValueKey('shaken');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RetryShake(
              child: SizedBox(key: childKey, width: 40, height: 40),
            ),
          ),
        ),
      );
      // Flushes flutter_animate's zero-duration startup timer — see the
      // matching comment on pumpAndFinishIntro in high_low_screen_test.dart.
      await tester.pump();
      await tester.pump(Duration.zero);

      final rest = tester.getTopLeft(find.byKey(childKey));

      final samples = <Offset>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        samples.add(tester.getTopLeft(find.byKey(childKey)));
      }
      expect(
        samples.length,
        greaterThan(1),
        reason: 'it must actually move while it is running',
      );

      await tester.pump(RetryShake.duration);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'a one-shot: nothing left running once the duration is up',
      );
      expect(tester.getTopLeft(find.byKey(childKey)), rest);

      // A long retry line would keep the widget mounted much longer than
      // the shake itself — it must stay still for all of it.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.getTopLeft(find.byKey(childKey)), rest);
    },
  );
}

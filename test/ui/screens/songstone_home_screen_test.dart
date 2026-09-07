import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/ui/components/adult_door.dart';
import 'package:ear_trainer/ui/screens/credits_screen.dart';
import 'package:ear_trainer/ui/screens/songstone_home_screen.dart';

void main() {
  group('SongStoneHomeScreen', () {
    testWidgets(
      'has exactly one AdultDoor, and it reaches the credits screen — '
      'Trello card rDHLTn8u: "tell me how to reach the door"',
      (tester) async {
        final router = GoRouter(
          initialLocation: AppRoutes.landing,
          routes: [
            GoRoute(
              path: AppRoutes.landing,
              builder: (context, state) => const SongStoneHomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.credits,
              builder: (context, state) => const CreditsScreen(),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        expect(find.byType(AdultDoor), findsOneWidget);

        await tester.tap(find.byType(AdultDoor));
        await tester.pumpAndSettle();

        expect(find.byType(CreditsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'the door sits well clear of the three menu pills — it should read '
      'as a separate, out-of-the-way control, not a fourth item in that '
      'row',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: const SongStoneHomeScreen()));
        await tester.pump();
        // The menu pills' entrance animation is staggered up to 300ms
        // (see _MenuPill's `delay`), implemented as a one-shot delayed
        // Timer — not pumpAndSettle, since the wordmark's own animation
        // repeats forever and never settles; elapsing past the longest
        // delay is enough to let that Timer fire so it isn't still
        // pending when the test tears down.
        await tester.pump(const Duration(milliseconds: 350));

        final doorRect = tester.getRect(find.byType(AdultDoor));
        for (final label in ['Playground', 'Learning Path', 'Games']) {
          final pillRect = tester.getRect(find.text(label));
          expect(
            doorRect.overlaps(pillRect),
            isFalse,
            reason: 'door overlaps the "$label" pill',
          );
        }
      },
    );
  });
}

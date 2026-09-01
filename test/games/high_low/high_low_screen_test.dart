import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/ui/components/progress_dots.dart';

void main() {
  // iPhone SE in landscape — the tightest realistic viewport this screen
  // has to fit into.
  const tightViewport = Size(667, 375);
  // iPhone 14 landscape — a roomier, more typical viewport, so the drag
  // path is proven to reach the scene at more than just the tight extreme.
  const roomyViewport = Size(844, 390);

  Future<void> pumpAndFinishIntro(
    WidgetTester tester, {
    Size viewport = tightViewport,
  }) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    await tester.pumpWidget(const MaterialApp(home: HighLowScreen()));

    // Advance past the postFrameCallback that starts the game and both
    // 2300ms note-ring waits the intro holds — one between the two notes,
    // one after the second so its wiggle/glow is actually visible for a
    // frame before the round hands off to awaitingInput (Trello card
    // 57/58/97 — was 800ms/single-wait, too short for the ~1.65s note
    // samples and too fast to paint the second instrument as playing at
    // all). Not pumpAndSettle — Clef and the glow/wiggle treatment use
    // repeating animations that never settle (same reason
    // test/widget_test.dart avoids it).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    // The last pump's frame rebuilds a status/caption widget with a new
    // ValueKey, which remounts its Animate wrapper and schedules a fresh
    // zero-duration startup Timer (flutter_animate's `Animate._restart`)
    // *during* that pump's own frame — too late for that same call's
    // `elapse()` to fire it. A bare `pump()` (null duration) skips
    // `elapse()` entirely and would never fire it either, so this needs
    // one more pump with an explicit (if zero) duration to actually
    // process it.
    await tester.pump(Duration.zero);

    // Piper/Clef are sized only by `height:` (see _buildPiper/_buildClef),
    // so their actual on-screen width comes from the *decoded* image's
    // aspect ratio and reads as zero until that decode finishes. That
    // decode is real async I/O (disk read + dart:ui codec), which doesn't
    // run on flutter_test's simulated pump clock — normally invisible since
    // paint alone doesn't need it, but a hit test against a still-zero-width
    // box always misses, so anything that hit-tests or drags the narrator
    // needs the decode to have actually finished first. `runAsync` steps
    // outside the fake clock to let that real Future resolve; the pump
    // after it picks up the now-correct layout.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  testWidgets('lays out cleanly on a tight landscape viewport without overflow '
      '(regression test for Trello card 46 — a FittedBox wrapping a Stack '
      'whose children are all Positioned silently collapses to zero width, '
      'which release builds render as garbled/misplaced content instead of '
      'throwing, so this needs an explicit check rather than eyeballing a '
      'screenshot)', (tester) async {
    await pumpAndFinishIntro(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(HighLowScreen), findsOneWidget);
  });

  testWidgets(
    'defaults to Trigger: round 1 is always a "higher" target (blocked '
    'order), so a draggable Clef and a first-person "put me on the high '
    'one" prompt are shown once the intro finishes (Trello card 101 — '
    'Clef owns the high pole, so she is the one speaking and dragged)',
    (tester) async {
      await pumpAndFinishIntro(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(Draggable<Object>), findsOneWidget);
      expect(find.textContaining('put me on the high'), findsOneWidget);
    },
  );

  testWidgets('the move-on arrow is always enabled, even mid-intro', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    await tester.pumpWidget(const MaterialApp(home: HighLowScreen()));
    await tester.pump(); // still mid-intro here — no time has advanced

    final moveOnButton = find.byTooltip('Move on');
    expect(moveOnButton, findsOneWidget);
    // The close (X) button should also always be present per the shared
    // game-screen control layout.
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(moveOnButton);
    await tester.pump();
    // Advancing rebuilds caption/status widgets with new ValueKeys, which
    // remounts their Animate wrappers and schedules a fresh zero-duration
    // startup Timer (flutter_animate's `Animate._restart`) — see the
    // matching comment on pumpAndFinishIntro above.
    await tester.pump(Duration.zero);

    expect(
      tester.widget<ProgressDots>(find.byType(ProgressDots)).currentIndex,
      1,
      reason:
          'a tiring child needs Move On to work even mid-intro, not just '
          'once a round happens to reach awaitingInput',
    );
  });

  for (final entry in {
    'tight landscape (iPhone SE)': tightViewport,
    'roomier landscape (iPhone 14)': roomyViewport,
  }.entries) {
    testWidgets('the draggable narrator and both instrument drop targets are '
        'hit-testable on a ${entry.key} viewport — regression test for the '
        "body's SingleChildScrollView sitting in front of the scene in "
        "GameScreenLayout's background layer and silently absorbing every "
        'touch before it reached the drag interaction (a Scrollable '
        'hit-tests its whole viewport, not just where it paints)', (
      tester,
    ) async {
      await pumpAndFinishIntro(tester, viewport: entry.value);

      expect(
        find.byType(Draggable<Object>).hitTestable(),
        findsOneWidget,
        reason: 'the dragged narrator must be reachable by touch',
      );
      expect(
        find.byType(DragTarget<Object>).hitTestable(),
        findsNWidgets(2),
        reason: 'both instrument drop targets must be reachable by touch',
      );
    });
  }

  testWidgets(
    'dragging the narrator onto an instrument and releasing completes a '
    'round — proves the touch actually lands on a DragTarget end-to-end, '
    "not just that the widgets are hit-testable in isolation. The round's "
    "target side is unseeded/random, so this drags onto one side and, if "
    "that wasn't the target (a gentle retry, not a failure state), "
    'immediately retries on the other side — one of the two is guaranteed '
    'correct, so completedCount reaching 1 proves a drop was accepted.',
    (tester) async {
      await pumpAndFinishIntro(tester);

      final narrator = find.byType(Draggable<Object>);
      final targets = find.byType(DragTarget<Object>);
      expect(targets, findsNWidgets(2));

      Future<void> dragOnto(Finder target) async {
        final start = tester.getCenter(narrator);
        final end = tester.getCenter(target);
        final gesture = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 20));
        const steps = 10;
        for (var i = 1; i <= steps; i++) {
          await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
          await tester.pump(const Duration(milliseconds: 20));
        }
        await gesture.up();
        await tester.pump();
        // The drop rebuilds caption/status widgets with new ValueKeys,
        // remounting their Animate wrappers and scheduling a fresh
        // zero-duration startup Timer (flutter_animate's `Animate._restart`)
        // — see the matching comment on pumpAndFinishIntro above.
        await tester.pump(Duration.zero);
      }

      await dragOnto(targets.at(0));

      var completedCount = tester
          .widget<ProgressDots>(find.byType(ProgressDots))
          .completedCount;

      if (completedCount == 0) {
        // First side was the wrong target — a gentle retry, not a failure
        // state (see HighLowGameState.dropOnSide) — so the round is still
        // live and a second drop is accepted immediately. The other side
        // is then guaranteed correct.
        await dragOnto(targets.at(1));
        completedCount = tester
            .widget<ProgressDots>(find.byType(ProgressDots))
            .completedCount;
      }

      expect(tester.takeException(), isNull);
      expect(
        completedCount,
        1,
        reason: 'a completed drag-and-drop must record the round as answered',
      );
    },
  );

  group('"Report this round" button (Trello card on0EymSu)', () {
    tearDown(() {
      // devToolsEnabled is a mutable, session-wide flag (see
      // app/config.dart) — reset it so one test's override never leaks
      // into the next.
      devToolsEnabled = false;
    });

    testWidgets('is absent for a public build (devToolsEnabled false)', (
      tester,
    ) async {
      devToolsEnabled = false;

      await tester.pumpWidget(const MaterialApp(home: HighLowScreen()));
      await tester.pump();
      // Flushes flutter_animate's zero-duration startup timer — see the
      // matching comment on pumpAndFinishIntro above.
      await tester.pump(Duration.zero);

      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });

    testWidgets(
      'appears in the header once the dev gate is dismissed, gated the '
      'same way as the rest of the dev tools',
      (tester) async {
        devToolsEnabled = true;

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => DevSettingsState(),
              child: const HighLowScreen(),
            ),
          ),
        );
        await tester.pump();

        // devToolsEnabled true means the debug-only setup gate (Trello
        // card 92) shows first — same guard as the report button.
        expect(find.byIcon(Icons.ios_share_rounded), findsNothing);

        await tester.tap(find.text('Start'));
        await tester.pump();
        // Flushes flutter_animate's zero-duration startup timer — see the
        // matching comment on pumpAndFinishIntro above.
        await tester.pump(Duration.zero);

        expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      },
    );
  });
}

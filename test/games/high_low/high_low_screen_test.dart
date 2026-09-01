import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/ui/components/progress_dots.dart';

void main() {
  Future<void> pumpAndFinishIntro(WidgetTester tester) async {
    // iPhone SE in landscape — the tightest realistic viewport this
    // screen has to fit into.
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(667, 375);
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
}

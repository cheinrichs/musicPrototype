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
    'order), so both instruments are draggable and a caption naming Clef '
    'is shown once the intro finishes (Trello card 101 — Clef owns the '
    'high pole, so she is the one centered and spoken for; Trello, '
    '"reverse the A2 drag interaction" — the instruments are what get '
    'dragged, not Clef herself)',
    (tester) async {
      await pumpAndFinishIntro(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(Draggable<int>), findsNWidgets(2));
      expect(find.textContaining('Clef'), findsOneWidget);
    },
  );

  testWidgets('the caption never renders flush against the close button — '
      'regression test for Trello card hIKjobsB, found driving the '
      'simulator: a long Trigger caption ("Drag the higher-sounding '
      'instrument to Clef.") needs nearly the full width Expanded gives it, '
      'and with no explicit margin its own left edge landed exactly on the '
      'close button\'s right edge — no true overlap, but no breathing room '
      'either, which reads as the caption running underneath the button', (
    tester,
  ) async {
    await pumpAndFinishIntro(tester, viewport: tightViewport);

    final closeRect = tester.getRect(find.byTooltip('Close'));
    final captionRect = tester.getRect(find.textContaining('Clef'));

    expect(
      captionRect.left,
      greaterThan(closeRect.right),
      reason: 'the caption must start to the right of the close button',
    );
    expect(
      captionRect.left - closeRect.right,
      greaterThanOrEqualTo(4.0),
      reason: 'there must be a real margin, not just adjacency',
    );
  });

  testWidgets('the skip pill is always enabled, even mid-intro', (
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

    final skipPill = find.byTooltip('Skip');
    expect(skipPill, findsOneWidget);
    // The close (X) button should also always be present per the shared
    // game-screen control layout.
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(skipPill);
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
    testWidgets('both draggable instruments and the single drop target are '
        'hit-testable on a ${entry.key} viewport — regression test for the '
        "body's SingleChildScrollView sitting in front of the scene in "
        "GameScreenLayout's background layer and silently absorbing every "
        'touch before it reached the drag interaction (a Scrollable '
        'hit-tests its whole viewport, not just where it paints)', (
      tester,
    ) async {
      await pumpAndFinishIntro(tester, viewport: entry.value);

      expect(
        find.byType(Draggable<int>).hitTestable(),
        findsNWidgets(2),
        reason: 'both draggable instruments must be reachable by touch',
      );
      expect(
        find.byType(DragTarget<int>).hitTestable(),
        findsOneWidget,
        reason:
            'the single, screen-spanning drop target must be reachable '
            'by touch',
      );
    });
  }

  testWidgets(
    'dragging an instrument onto the character and releasing completes a '
    'round — proves the touch actually lands on the DragTarget end-to-end, '
    "not just that the widgets are hit-testable in isolation. The round's "
    "target side is unseeded/random, so this drags one instrument and, if "
    "that wasn't the target (a gentle retry, not a failure state), "
    'immediately retries with the other instrument — one of the two is '
    'guaranteed correct, so completedCount reaching 1 proves a drop was '
    'accepted.',
    (tester) async {
      await pumpAndFinishIntro(tester);

      final instruments = find.byType(Draggable<int>);
      final target = find.byType(DragTarget<int>);
      expect(instruments, findsNWidgets(2));
      expect(target, findsOneWidget);

      Future<void> dragOnto(Finder instrument) async {
        final start = tester.getCenter(instrument);
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

      await dragOnto(instruments.at(0));

      var completedCount = tester
          .widget<ProgressDots>(find.byType(ProgressDots))
          .completedCount;

      if (completedCount == 0) {
        // First instrument was wrong — a gentle retry, not a failure state
        // (see HighLowGameState.dropInstrument) — so the round is still
        // live and a second drop is accepted immediately. The other
        // instrument is then guaranteed correct.
        await dragOnto(instruments.at(1));
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

  testWidgets(
    'the single drop target spans the entire play area, not a small box '
    "hugging the centered character — a four-year-old's aim is imprecise, "
    'so the hitbox needs to be substantially bigger than what it visually '
    'sits on top of (Trello — "forgiving drop targets," now applied to the '
    'character-as-target instead of the instruments)',
    (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);

      final target = find.byType(DragTarget<int>);
      expect(target, findsOneWidget);

      final targetSize = tester.getSize(target);

      // The centered character is a fraction of screen height (see
      // _buildScene's clefHeight/piperHeight) — a drop target that's
      // merely as big as her would match that; this asserts it's
      // dramatically bigger in both dimensions, since it's meant to span
      // the whole scene.
      expect(
        targetSize.width,
        closeTo(roomyViewport.width, 1.0),
        reason: 'the drop target should span the full play-area width',
      );
      expect(
        targetSize.height,
        closeTo(roomyViewport.height, 1.0),
        reason: 'the drop target should span the full play-area height',
      );
    },
  );

  testWidgets(
    'a drop anywhere on screen completes the round, even far from both the '
    "centered character and the dragged instrument's own small silhouette "
    '— proves the enlarged target actually accepts a forgiving drop '
    'end-to-end, not just that it measures big (Trello — "forgiving drop '
    'targets")',
    (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);

      final instruments = find.byType(Draggable<int>);
      final target = find.byType(DragTarget<int>);
      expect(instruments, findsNWidgets(2));
      expect(target, findsOneWidget);

      // Drop near the very top corner of the screen — as far from the
      // centered character and the ground-level instrument as this play
      // area gets.
      Future<void> dragToCorner(int instrumentIndex) async {
        final targetRect = tester.getRect(target);
        final end = Offset(
          instrumentIndex == 0 ? targetRect.left + 4 : targetRect.right - 4,
          targetRect.top + 4,
        );
        final start = tester.getCenter(instruments.at(instrumentIndex));
        final gesture = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 20));
        const steps = 10;
        for (var i = 1; i <= steps; i++) {
          await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
          await tester.pump(const Duration(milliseconds: 20));
        }
        await gesture.up();
        await tester.pump();
        await tester.pump(Duration.zero);
      }

      await dragToCorner(0);
      var completedCount = tester
          .widget<ProgressDots>(find.byType(ProgressDots))
          .completedCount;

      if (completedCount == 0) {
        // Same "wrong instrument retries immediately" reasoning as the
        // drag test above — one of the two is guaranteed correct.
        await dragToCorner(1);
        completedCount = tester
            .widget<ProgressDots>(find.byType(ProgressDots))
            .completedCount;
      }

      expect(tester.takeException(), isNull);
      expect(
        completedCount,
        1,
        reason:
            'a drop far from the character and the instrument\'s own '
            'silhouette, but still on screen, must still register',
      );
    },
  );

  testWidgets(
    'the adult move-on control appears ~6s into an unanswered round '
    '(default agency is Trigger) and resolves the round when tapped '
    '(Trello card xpAkja5b)',
    (tester) async {
      await pumpAndFinishIntro(tester);

      expect(
        find.byIcon(Icons.check_circle_outline),
        findsNothing,
        reason: 'never visible immediately',
      );

      await tester.pump(const Duration(seconds: 6));

      final moveOnControl = find.byIcon(Icons.check_circle_outline);
      expect(moveOnControl, findsOneWidget);

      await tester.tap(moveOnControl);
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(
        tester.widget<ProgressDots>(find.byType(ProgressDots)).completedCount,
        1,
        reason: 'unlike Skip, moveOn resolves the round as answered',
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

    testWidgets(
      'tapping it gives an immediate spinner and, when sharing fails (as it '
      "always will in a widget test — there's no real platform to hand the "
      'share sheet to), surfaces that failure instead of silently doing '
      'nothing (Cooper: "when I click the send button, nothing appears to '
      'happen")',
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
        await tester.tap(find.text('Start'));
        await tester.pump();
        await tester.pump(Duration.zero);

        // Advance past the intro so there's a current prompt to report.
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(Duration.zero);

        final shareButton = find.byIcon(Icons.ios_share_rounded);
        expect(shareButton, findsOneWidget);

        await tester.tap(shareButton);
        // One frame, no time elapsed — proves the spinner is *immediate*,
        // not something that only shows up once the capture/share work
        // (which hasn't had a chance to run at all yet) finishes.
        await tester.pump();
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason:
              'a tap needs a visible response before the slow work even '
              'starts, not just once it finishes',
        );

        // Let the actual capture/share run. There's no platform channel
        // implementation in a widget test, so this fails for real — a
        // genuine (if incidental) exercise of the error path, not a stub.
        // Not pumpAndSettle: this screen's idle-bob animations repeat
        // forever and never settle (same reason pumpAndFinishIntro above
        // avoids it) — and BuildInfo/file-I/O/Share are real async work,
        // not fake-clock timers, so runAsync is what actually lets them
        // run and fail rather than just pumping fake frames.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 6)),
        );
        await tester.pump();

        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason:
              'the spinner must clear once the attempt finishes, '
              'success or failure',
        );
        expect(
          find.text("Couldn't share this round's report."),
          findsOneWidget,
          reason:
              'a failure must be visible, not swallowed the way it was '
              'before (Cooper\'s report)',
        );
      },
    );
  });

  group('three-note tier placeholder (Trello card "Rebuild the tier ladder as '
      'eight tiers (2x2x2)")', () {
    tearDown(() {
      devToolsEnabled = false;
    });

    testWidgets(
      'picking a three-note tier (T5-T8) shows a placeholder instead of '
      'starting the game — there is no screen for a third instrument '
      'yet, and this must not crash or render a broken two-slot layout '
      'for it',
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

        await tester.tap(find.text('T5'));
        await tester.pump();
        await tester.tap(find.text('Start'));
        await tester.pump();

        expect(find.textContaining("aren't built yet"), findsOneWidget);
        expect(find.text('Dev: agency setup'), findsNothing);
        expect(
          find.byType(DragTarget<int>),
          findsNothing,
          reason: 'no game state was started, so no drop target either',
        );

        await tester.tap(find.text('Back to tier picker'));
        await tester.pump();
        expect(find.text('Dev: agency setup'), findsOneWidget);
      },
    );

    testWidgets(
      'a two-note tier (the T1 default) starts the real game, not the '
      'placeholder',
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

        await tester.tap(find.text('Start'));
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(find.textContaining("aren't built yet"), findsNothing);
      },
    );
  });
}

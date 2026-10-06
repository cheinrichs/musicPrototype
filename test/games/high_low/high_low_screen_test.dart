import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_screen.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/games/high_low/services/agency_advancement.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_slot.dart';
import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_pulse.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_caption.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/round_order.dart';
import 'package:ear_trainer/ui/components/progress_dots.dart';

void main() {
  // Only the new "dev gate scoped to the adult profile" group below
  // actually constructs a ProfileState; harmless for every other test in
  // this file.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // iPhone SE in landscape — the tightest realistic viewport this screen
  // has to fit into.
  const tightViewport = Size(667, 375);
  // iPhone 14 landscape — a roomier, more typical viewport, so the drag
  // path is proven to reach the scene at more than just the tight extreme.
  const roomyViewport = Size(844, 390);

  /// The state behind the screen [pumpAndFinishIntro] mounted — tests read
  /// progress (rounds completed, current round) from it directly now that the
  /// on-screen progress indicator is gone.
  late HighLowGameState screenState;

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

    final state = HighLowGameState();
    screenState = state;
    await tester.pumpWidget(
      MaterialApp(home: HighLowScreen(gameState: state, ownsGameState: true)),
    );

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
    'order), so both instruments are draggable and a caption asking for '
    'the higher one is shown once the intro finishes (Trello card 101 — '
    'Clef owns the high pole; Trello, "reverse the A2 drag interaction" — '
    'the instruments are what get dragged, not a character)',
    (tester) async {
      await pumpAndFinishIntro(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(Draggable<int>), findsNWidgets(2));
      expect(find.textContaining('higher'), findsOneWidget);
    },
  );

  testWidgets('the caption never renders flush against the close button — '
      'regression test for Trello card hIKjobsB, found driving the '
      'simulator: a long Trigger caption ("Help them drag the higher '
      'instrument up the tree.") needs nearly the full width Expanded gives '
      'it, and with no explicit margin its own left edge landed exactly on '
      'the close button\'s right edge — no true overlap, but no breathing '
      'room either, which reads as the caption running underneath the '
      'button', (tester) async {
    await pumpAndFinishIntro(tester, viewport: tightViewport);

    final closeRect = tester.getRect(find.byTooltip('Close'));
    final captionRect = tester.getRect(find.textContaining('higher'));

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

    final state = HighLowGameState();
    screenState = state;
    await tester.pumpWidget(
      MaterialApp(home: HighLowScreen(gameState: state, ownsGameState: true)),
    );
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
      screenState.currentPromptIndex,
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
        reason: 'the one tree slot must be reachable by touch',
      );
    });
  }

  testWidgets(
    'dragging an instrument onto the tree slot and releasing completes a '
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

      var completedCount = screenState.results.length;

      if (completedCount == 0) {
        // First instrument was wrong — a gentle retry, not a failure state
        // (see HighLowGameState.dropInstrument) — so the round is still
        // live and a second drop is accepted immediately. The other
        // instrument is then guaranteed correct.
        await dragOnto(instruments.at(1));
        completedCount = screenState.results.length;
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
    'the tree slot\'s hitbox is generous — wider than the platform\'s own '
    'face, matching the A4 ordering screen\'s slots, so a four-year-old\'s '
    'imprecise aim still lands it — but it is no longer the *whole play '
    'area* now that the target is a positioned slot rather than a '
    'screen-spanning zone (2026-09-27, superseding "forgiving drop '
    'targets" — a slot the child can genuinely miss is the point: a miss '
    'must not silently count)',
    (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);

      final target = find.byType(DragTarget<int>);
      expect(target, findsOneWidget);
      final targetSize = tester.getSize(target);

      expect(
        targetSize.width,
        lessThan(roomyViewport.width * 0.5),
        reason: 'not the whole screen any more',
      );
      expect(
        targetSize.height,
        lessThan(roomyViewport.height * 0.5),
        reason: 'not the whole screen any more',
      );
      expect(targetSize.width, greaterThan(20));
      expect(targetSize.height, greaterThan(20));
    },
  );

  testWidgets(
    'a drop that misses the slot does nothing — no wrongness recorded, the '
    'instrument simply stays where it was, and the round is not resolved '
    '(2026-09-27: now that the target is one positioned slot rather than '
    'the whole screen, a genuine miss is possible, and must not silently '
    'count the way any old screen-spanning drop used to)',
    (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);

      final instruments = find.byType(Draggable<int>);
      expect(instruments, findsNWidgets(2));

      // Top-left corner: far from the slot (which sits up near the tree,
      // on the right) and far from the stumps too.
      const end = Offset(20, 20);
      final start = tester.getCenter(instruments.at(0));
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

      expect(tester.takeException(), isNull);
      expect(
        screenState.results.length,
        0,
        reason: 'a miss must not be recorded as an attempt at all',
      );
      expect(
        screenState.dragFeedback,
        DragFeedback.none,
        reason: 'a miss is not a wrong answer — nothing marks it',
      );
    },
  );

  group('both characters live on the tree, at every agency level', () {
    tearDown(() {
      devToolsEnabled = false;
    });

    /// The rendered rect of each character's resting (mouth) frame.
    Rect frameRect(WidgetTester tester, String name) => tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.endsWith(name),
      ),
    );

    Future<void> startAt(WidgetTester tester, String agencyChip) async {
      devToolsEnabled = true;
      tester.view.physicalSize = roomyViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A fresh element tree each call: reusing the same MaterialApp shape
      // across two calls in one test (see the "NO tree slot" test, which
      // calls this twice) would let Flutter reconcile it as an update to
      // the SAME State rather than a new screen, so `_showDevGate` (already
      // false from the first call) would stay false and the dev gate would
      // never reappear.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => DevSettingsState(),
            child: const HighLowScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(agencyChip));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(Duration.zero);
    }

    for (final chip in ['A0 · Observe', 'A1 · Explore', 'A2 · Decide']) {
      testWidgets(
        '$chip: Clef is on the tree; Piper stands beside it on the ground, '
        'clearly bigger (2026-09-27: she used to perch on a lower platform '
        'and rendered tiny — Cooper: "have her standing beside the tree ... '
        'at her proper scale"). Neither changes size with the task — there '
        'is no centre character to compete with the middle',
        (tester) async {
          await startAt(tester, chip);

          final clef = frameRect(tester, 'clef_mouth_0.png');
          final piper = frameRect(tester, 'piper_mouth_0.png');
          expect(
            piper.height,
            greaterThan(clef.height * 1.5),
            reason: 'foreground scale, not the tree\'s perch size',
          );
          // both on the right of the frame — Clef on the tree, Piper beside
          // it — not the centre.
          for (final r in [clef, piper]) {
            expect(r.center.dx, greaterThan(roomyViewport.width * 0.5));
          }
        },
      );
    }

    testWidgets(
      'A0 · Observe and A1 · Explore show NO tree slot — nothing can be '
      'placed at either stage, and an empty receptacle is a false '
      'affordance a two-year-old would spend real time failing at',
      (tester) async {
        for (final chip in ['A0 · Observe', 'A1 · Explore']) {
          await startAt(tester, chip);
          expect(find.byType(OrderingSlot), findsNothing, reason: chip);
          expect(find.text('?'), findsNothing, reason: chip);
        }
      },
    );

    testWidgets(
      'A2 · Decide shows exactly one tree slot — the drop target, now that '
      'something can actually be placed',
      (tester) async {
        await startAt(tester, 'A2 · Decide');
        expect(find.byType(OrderingSlot), findsOneWidget);
      },
    );
  });

  testWidgets(
    'the character who is not speaking is never made transparent — reduced '
    'opacity reads as "unavailable", which is wrong for a character who is '
    'simply present and not the one talking (Cooper: "i don\'t like that"). '
    'Dimming was an opacity wrapper around the sprite, so no such wrapper '
    'may exist at all (speaking cannot be observed here: with no audio a '
    'spoken line finishes before the next frame)',
    (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);

      expect(find.byType(CharacterSprite), findsNWidgets(2));
      for (final sprite in find.byType(CharacterSprite).evaluate()) {
        final wrappers = find.ancestor(
          of: find.byWidget(sprite.widget),
          matching: find.byWidgetPredicate(
            (w) => w is Opacity || w is AnimatedOpacity,
          ),
        );
        expect(
          wrappers,
          findsNothing,
          reason: 'nothing may fade a character as a whole',
        );
      }
    },
  );

  group('a tap or a short accidental drag never answers at Trigger '
      '(Trello card L00pxs7q)', () {
    testWidgets(
      'a plain tap on either instrument plays it but never resolves the round',
      (tester) async {
        await pumpAndFinishIntro(tester, viewport: roomyViewport);
        final instruments = find.byType(Draggable<int>);

        for (final i in [0, 1]) {
          await tester.tap(instruments.at(i));
          await tester.pump();
          await tester.pump(Duration.zero);
        }

        expect(tester.takeException(), isNull);
        expect(
          screenState.results.length,
          0,
          reason: 'a tap is exploration — only a drag answers at Trigger',
        );
      },
    );

    testWidgets(
      'a short drag that barely clears the touch slop — a finger that slid '
      'during a tap — never resolves the round, on either instrument',
      (tester) async {
        await pumpAndFinishIntro(tester, viewport: roomyViewport);
        final instruments = find.byType(Draggable<int>);

        for (final i in [0, 1]) {
          final start = tester.getCenter(instruments.at(i));
          final gesture = await tester.startGesture(start);
          await tester.pump(const Duration(milliseconds: 20));
          // 30px: past the ~18px touch slop that starts a Draggable, but a
          // tiny fraction of the ~200px trip to the centered character.
          await gesture.moveTo(start + const Offset(30, 0));
          await tester.pump(const Duration(milliseconds: 20));
          await gesture.up();
          await tester.pump();
          await tester.pump(Duration.zero);
        }

        expect(tester.takeException(), isNull);
        expect(
          screenState.results.length,
          0,
          reason:
              'one of the two instruments is the correct one — a 30px slide '
              'must not be read as the answer',
        );
      },
    );
  });

  group('the earned arrow (Trello card xpAkja5b)', () {
    tearDown(() {
      devToolsEnabled = false;
    });

    testWidgets(
      'appears only once both instruments have been tapped, never on a '
      'timer, and resolves the round when tapped',
      (tester) async {
        tester.view.physicalSize = roomyViewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Observe (A0) — the earned arrow only ever appears there.
        final state = HighLowGameState(agencyStage: AgencyStage.observe);
        screenState = state;
        await tester.pumpWidget(
          MaterialApp(
            home: HighLowScreen(gameState: state, ownsGameState: true),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump(Duration.zero);

        // Same real-decode wait as pumpAndFinishIntro (see its comment):
        // a hit test against a not-yet-sized image box always misses, so
        // without this the taps below race the asset decode — this test
        // passed on CI and locally only by winning that race.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();

        // Observe's instruments aren't Draggable (that's Trigger-only), so
        // find them by their private button type rather than by
        // hard-coded coordinates copied from _buildScene's layout math.
        final instruments = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_InstrumentButton',
        );
        expect(instruments, findsNWidgets(2));
        final leftInstrument = tester.getCenter(instruments.at(0));
        final rightInstrument = tester.getCenter(instruments.at(1));

        // Long past where the old timed move-on control would have
        // appeared — still nothing, because nothing's been tapped yet.
        await tester.pump(const Duration(seconds: 10));
        expect(
          find.byIcon(Icons.arrow_forward_rounded),
          findsNothing,
          reason: 'time alone must never reveal it',
        );

        await tester.tapAt(leftInstrument);
        await tester.pump();
        expect(
          find.byIcon(Icons.arrow_forward_rounded),
          findsNothing,
          reason: 'only one of the two instruments has been tapped so far',
        );

        await tester.tapAt(rightInstrument);
        await tester.pump();
        final arrow = find.byIcon(Icons.arrow_forward_rounded);
        expect(arrow, findsOneWidget);

        await tester.tap(arrow);
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(
          screenState.results.length,
          1,
          reason: 'tapping the earned arrow resolves the round as complete',
        );
      },
    );
  });

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

  group('the ordering skill hands off to the ordering screen', () {
    tearDown(() {
      devToolsEnabled = false;
    });

    for (final chip in ['T1', 'T5']) {
      testWidgets('picking the Ordering skill with $chip in the dev gate opens '
          'ordering — including a three-note tier, which the placeholder no '
          'longer covers here. Ordering is a separate skill, not a fourth '
          'AgencyStage (Trello card 168), so it is its own toggle rather than '
          'a chip in the Agency row', (tester) async {
        devToolsEnabled = true;
        tester.view.physicalSize = roomyViewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => DevSettingsState(),
              child: const HighLowScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Ordering'));
        await tester.pump();
        await tester.tap(find.text(chip));
        await tester.pump();
        await tester.tap(find.text('Start'));
        await tester.pump();
        await tester.pump(Duration.zero);
        await tester.pump(Duration.zero);

        expect(find.byType(OrderingScreen), findsOneWidget);
        expect(find.textContaining('not built'), findsNothing);

        // Unmount so the screen's opening playback timers are cancelled
        // with it rather than left pending.
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('poses, prominence and the layout pass (Cooper, on device)', () {
    /// Asset names of every character image currently showing (opacity 1).
    Set<String> showing(WidgetTester tester) {
      final result = <String>{};
      for (final o
          in find
              .descendant(
                of: find.byType(CharacterSprite),
                matching: find.byType(Opacity),
              )
              .evaluate()) {
        if ((o.widget as Opacity).opacity != 1.0) continue;
        final image =
            find
                    .descendant(
                      of: find.byWidget(o.widget),
                      matching: find.byType(Image),
                    )
                    .evaluate()
                    .single
                    .widget
                as Image;
        result.add((image.image as AssetImage).assetName.split('/').last);
      }
      return result;
    }

    /// A round whose answer is known: seeded generator, Trigger, blocked.
    Future<HighLowGameState> pumpKnownRound(
      WidgetTester tester, {
      AgencyStage? stage,
    }) async {
      tester.view.physicalSize = roomyViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final state = stage == null
          ? HighLowGameState(
              totalPrompts: 3,
              generator: PromptGenerator(random: Random(1)),
            )
          : HighLowGameState(
              totalPrompts: 3,
              agencyStage: stage,
              generator: PromptGenerator(random: Random(1)),
            );
      await tester.pumpWidget(
        MaterialApp(home: HighLowScreen(gameState: state)),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1200));
      }
      await tester.pump(Duration.zero);
      // Same real-decode wait as pumpAndFinishIntro: a hit test against a
      // not-yet-sized image box always misses, so a drag would never start.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      return state;
    }

    Future<void> dragSide(WidgetTester tester, int side) async {
      final start = tester.getCenter(find.byType(Draggable<int>).at(side));
      final end = tester.getCenter(find.byType(DragTarget<int>));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 20));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / 8)!);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(Duration.zero);
    }

    testWidgets('a wrong drop makes the drop target think — and only the '
        'target changes pose', (tester) async {
      final state = await pumpKnownRound(tester);
      await dragSide(tester, 1 - state.currentPrompt!.targetSide);

      final shown = showing(tester);
      expect(shown.where((n) => n.endsWith('thinking.png')).length, 1);
      expect(shown.where((n) => n.endsWith('celebration.png')), isEmpty);
      expect(
        shown.where((n) => n.contains('_mouth_')).length,
        1,
        reason: 'the one standing by just speaks',
      );
      state.dispose();
    });

    testWidgets('a correct drop makes the drop target celebrate — the payoff '
        'moment — and only the target changes pose', (tester) async {
      final state = await pumpKnownRound(tester);
      await dragSide(tester, state.currentPrompt!.targetSide);

      final shown = showing(tester);
      expect(shown.where((n) => n.endsWith('celebration.png')).length, 1);
      expect(shown.where((n) => n.endsWith('thinking.png')), isEmpty);
      expect(shown.where((n) => n.contains('_mouth_')).length, 1);
      state.dispose();
    });

    testWidgets('the celebrating character is painted in front of the '
        'instrument that lands on it — otherwise the payoff pose is hidden '
        '(caught in an offscreen render: the piano covered Clef)', (
      tester,
    ) async {
      final state = await pumpKnownRound(tester);
      final side = state.currentPrompt!.targetSide;
      final instrument = side == 0
          ? state.leftInstrument.leftAssetPath
          : state.rightInstrument.rightAssetPath;
      await dragSide(tester, side);
      await tester.pump(const Duration(milliseconds: 600));

      final order = tester.allElements.toList();
      final instrumentAt = order.indexWhere(
        (e) =>
            e.widget is Image &&
            ((e.widget as Image).image as AssetImage).assetName == instrument,
      );
      final celebrationAt = order.indexWhere((e) {
        final w = e.widget;
        return w is Opacity &&
            w.opacity == 1.0 &&
            find
                .descendant(
                  of: find.byWidget(w),
                  matching: find.byWidgetPredicate(
                    (x) =>
                        x is Image &&
                        (x.image as AssetImage).assetName.endsWith(
                          'celebration.png',
                        ),
                  ),
                )
                .evaluate()
                .isNotEmpty;
      });
      expect(instrumentAt, isNonNegative);
      expect(celebrationAt, isNonNegative);
      expect(celebrationAt, greaterThan(instrumentAt));
      state.dispose();
    });

    testWidgets('after a wrong drop she goes back to speaking, and a right '
        'one can follow it', (tester) async {
      final state = await pumpKnownRound(tester);
      final right = state.currentPrompt!.targetSide;
      await dragSide(tester, 1 - right);
      await dragSide(tester, right);

      expect(
        showing(tester).where((n) => n.endsWith('celebration.png')).length,
        1,
      );
      state.dispose();
    });

    // Device bug (Cooper): "the listening pose fires on a CORRECT tap at
    // Explore". It was never the tap — the six-second guidance caption drove
    // the pose, and its timer runs from round start whatever the child does.
    testWidgets('at Explore, correct taps after the six-second caption never '
        'get the thinking pose', (tester) async {
      final state = await pumpKnownRound(tester, stage: AgencyStage.explore);
      await tester.pump(const Duration(seconds: 7));
      expect(state.secondaryCaptionText, isNotNull, reason: 'caption is up');
      expect(showing(tester).where((n) => n.endsWith('thinking.png')), isEmpty);

      for (var tap = 1; tap <= 4; tap++) {
        state.tapInstrument(state.currentPrompt!.targetSide);
        await tester.pump();
        expect(
          showing(tester).where((n) => n.endsWith('thinking.png')),
          isEmpty,
          reason: 'correct tap $tap',
        );
        await tester.pump(const Duration(milliseconds: 1000));
      }
      state.dispose();
    });

    testWidgets('at Explore, the five-wrong-tap nudge makes the target think, '
        'for the nudge line or the retry minimum', (tester) async {
      final state = await pumpKnownRound(tester, stage: AgencyStage.explore);
      final wrong = 1 - state.currentPrompt!.targetSide;
      for (var tap = 1; tap <= 4; tap++) {
        state.tapInstrument(wrong);
        await tester.pump();
        expect(
          showing(tester).where((n) => n.endsWith('thinking.png')),
          isEmpty,
          reason: 'wrong tap $tap is below the five-tap rule',
        );
      }
      state.tapInstrument(wrong);
      await tester.pump();
      expect(
        showing(tester).where((n) => n.endsWith('thinking.png')).length,
        1,
      );
      expect(
        showing(tester).where((n) => n.contains('_mouth_')).length,
        1,
        reason: 'the one standing by just speaks',
      );

      // The test audio resolves lines at once, so the minimum dwell governs.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(showing(tester).where((n) => n.endsWith('thinking.png')), isEmpty);
      state.dispose();
    });

    testWidgets('at Explore, a correct tap during the nudge ends the thinking '
        'pose at once — a right answer is never met with doubt', (
      tester,
    ) async {
      final state = await pumpKnownRound(tester, stage: AgencyStage.explore);
      final target = state.currentPrompt!.targetSide;
      for (var tap = 1; tap <= 5; tap++) {
        state.tapInstrument(1 - target);
      }
      await tester.pump();
      expect(
        showing(tester).where((n) => n.endsWith('thinking.png')).length,
        1,
      );

      state.tapInstrument(target);
      await tester.pump();
      expect(showing(tester).where((n) => n.endsWith('thinking.png')), isEmpty);
      await tester.pump(const Duration(milliseconds: 1500));
      state.dispose();
    });

    testWidgets('Piper has her own mouth frames — the stopgap sheet — and '
        'Clef has hers', (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);
      final names = {
        for (final e in find.byType(Image).evaluate())
          if ((e.widget as Image).image is AssetImage)
            ((e.widget as Image).image as AssetImage).assetName.split('/').last,
      };
      expect(names, containsAll(['piper_mouth_0.png', 'clef_mouth_0.png']));
    });

    testWidgets('on a notched phone no character crosses the safe area — '
        'Clef\'s right hand used to run off the screen', (tester) async {
      tester.view.physicalSize = roomyViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.symmetric(horizontal: 47)),
            child: child!,
          ),
          home: const HighLowScreen(),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1200));
      }
      await tester.pump(Duration.zero);

      for (final name in ['clef_mouth_0.png', 'piper_mouth_0.png']) {
        final rect = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName.endsWith(name),
          ),
        );
        expect(rect.left, greaterThanOrEqualTo(47 - 0.5), reason: name);
        expect(
          rect.right,
          lessThanOrEqualTo(roomyViewport.width - 47 + 0.5),
          reason: name,
        );
      }
    });

    testWidgets('the layout: close and Skip hug the true top corners, the '
        'caption is centred, Listen Again sits below the stumps (not under '
        'the caption — 2026-09-28, Cooper: "I like listen again below the '
        'stumps"), and there is no progress indicator', (tester) async {
      await pumpAndFinishIntro(tester, viewport: roomyViewport);
      final size = roomyViewport;

      final close = tester.getRect(find.byTooltip('Close'));
      final skip = tester.getRect(find.byTooltip('Skip'));
      final listen = tester.getRect(find.text('Listen Again'));
      final caption = tester.getRect(find.byType(HighLowCaption));

      expect(close.left, lessThan(size.width * 0.1));
      expect(close.center.dy, lessThan(size.height * 0.25));
      expect(skip.right, greaterThan(size.width * 0.9));
      expect(skip.center.dy, lessThan(size.height * 0.25));
      expect(skip.height, lessThanOrEqualTo(44));
      expect(caption.center.dx, closeTo(size.width / 2, 1.0));
      // Listen Again now lives in the scene, below the stumps on the left —
      // no longer under the (screen-centred) caption, and no longer
      // excluded from the bottom of the screen: that's exactly where it is
      // now, by design.
      expect(listen.top, greaterThan(caption.bottom));
      expect(listen.center.dx, lessThan(size.width * 0.5));
      expect(
        find.byType(ProgressDots),
        findsNothing,
        reason:
            'always five rounds, so it told the child nothing; see '
            'docs/product/HIGH_LOW_SCREEN_LAYOUT.md for what would bring it back',
      );
      expect(find.text('I want something new'), findsNothing);

      // Close and Skip stay out of the bottom band (still adult/escape
      // controls, up top per the thumb-reach principle); Listen Again is
      // deliberately excluded from this check now — it belongs low on
      // screen, below the stumps.
      final bottomBand = Rect.fromLTWH(
        0,
        size.height * 0.88,
        size.width,
        size.height * 0.12,
      );
      for (final r in [close, skip]) {
        expect(r.overlaps(bottomBand), isFalse);
      }
    });
  });

  group('the dev gate is scoped to the adult profile (Trello card 170: an '
      'internal build a child is using must not show dev tools either)', () {
    tearDown(() => devToolsEnabled = false);

    Future<void> pumpWithProfile(WidgetTester tester, Profile? profile) async {
      devToolsEnabled = true;
      final profileState = ProfileState();
      await profileState.load();
      if (profile != null) profileState.selectProfile(profile);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileState),
            ChangeNotifierProvider(create: (_) => DevSettingsState()),
          ],
          child: const MaterialApp(home: HighLowScreen()),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's zero-duration startup timer — see the
      // matching comment on pumpAndFinishIntro above.
      await tester.pump(Duration.zero);
    }

    testWidgets('shows for the adult profile', (tester) async {
      await pumpWithProfile(
        tester,
        const Profile(id: 'p1', name: 'Cooper', isAdult: true),
      );
      expect(find.text('Dev: agency setup'), findsOneWidget);
    });

    testWidgets('does not show for a child profile — the game auto-starts '
        'instead, same as a public build', (tester) async {
      await pumpWithProfile(
        tester,
        const Profile(id: 'p2', name: 'Davis', isAdult: false),
      );
      expect(find.text('Dev: agency setup'), findsNothing);
      // The game auto-started (correct) and its intro is now mid-flight
      // with its own pending timers — unmount rather than leave the test
      // to notice them as unfinished.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not show with no profile selected at all', (
      tester,
    ) async {
      await pumpWithProfile(tester, null);
      expect(find.text('Dev: agency setup'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('agency comes from the active profile, not a hard-coded default '
      '(Trello card 172)', () {
    tearDown(() => devToolsEnabled = false);

    testWidgets(
      'a fresh child profile with no override starts the game at Observe, '
      'not Drag — proven via Observe\'s own caption, since the screen '
      'exposes no other way to read its internal game state from outside',
      (tester) async {
        devToolsEnabled = false; // the real, public-build auto-start path
        final profileState = ProfileState();
        await profileState.load();
        profileState.selectProfile(await profileState.addProfile('Davis'));

        await tester.pumpWidget(
          MultiProvider(
            providers: [ChangeNotifierProvider.value(value: profileState)],
            child: const MaterialApp(home: HighLowScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(
          find.text('Encourage them to tap each instrument.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a profile with an existing override starts the game at that stage '
      'instead',
      (tester) async {
        devToolsEnabled = false;
        final profileState = ProfileState();
        await profileState.load();
        final davis = await profileState.addProfile('Davis');
        await profileState.setAgencyOverride(davis, AgencyStage.decide);
        profileState.selectProfile(
          profileState.profiles.firstWhere((p) => p.id == davis.id),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [ChangeNotifierProvider.value(value: profileState)],
            child: const MaterialApp(home: HighLowScreen()),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 1200));
        }
        await tester.pump(Duration.zero);

        // Drag is the only stage with a drop target.
        expect(find.byType(DragTarget<int>), findsOneWidget);
      },
    );

    testWidgets(
      'completing enough Observe rounds writes Explore back to the active '
      'profile, with a reason recorded (debugPrint, until a real tracking '
      'log exists)',
      (tester) async {
        final profileState = ProfileState();
        await profileState.load();
        final davis = await profileState.addProfile('Davis');
        profileState.selectProfile(davis);

        final state = HighLowGameState(
          totalPrompts: AgencyAdvancement.roundsRequired,
          agencyStage: AgencyStage.observe,
        );
        final router = GoRouter(
          initialLocation: AppRoutes.highLow,
          routes: [
            GoRoute(
              path: AppRoutes.highLow,
              builder: (context, _) =>
                  HighLowScreen(gameState: state, ownsGameState: true),
            ),
            GoRoute(
              path: AppRoutes.reward,
              builder: (context, _) => const Scaffold(body: Text('REWARD')),
            ),
          ],
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: profileState),
              ChangeNotifierProvider(create: (_) => ProgressState()),
              ChangeNotifierProvider(create: (_) => SkillState()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();

        // Complete every round directly on the game state — proving the
        // write-back only needs to observe [HighLowGameState.status]/
        // [HighLowGameState.instrumentation], not simulate every tap
        // through the UI (already covered elsewhere for the interaction
        // itself).
        for (
          var round = 0;
          round < AgencyAdvancement.roundsRequired - 1;
          round++
        ) {
          state.tapInstrument(0);
          state.tapInstrument(1);
          state.tapArrow();
          await tester.pump();
        }
        // The last round completes the session, which both writes the
        // agency change back (a real SharedPreferences save) and navigates
        // to the reward screen (its own flutter_animate startup timer) —
        // let both actually resolve before the test ends.
        state.tapInstrument(0);
        state.tapInstrument(1);
        state.tapArrow();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(
          profileState.profiles
              .firstWhere((p) => p.id == davis.id)
              .agencyOverride,
          AgencyStage.explore,
        );
      },
    );
  });

  group('speaking never moves a character (device bug, build 75: Piper and/or '
      'Clef briefly jumping to the top-left corner while talking)', () {
    // Settled-frame tests passed while this shipped, so this one samples
    // every frame of the voice lines instead. Explore and Drag both speak
    // from the round prompt, so both are covered; Observe only speaks on a
    // tap, so it is not sampled here.
    for (final stage in [AgencyStage.explore, AgencyStage.decide]) {
      testWidgets('each character\'s feet stay put on every frame, at '
          '${stage.label}', (tester) async {
        tester.view.physicalSize = roomyViewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // The real AudioController resolves a voice line instantly under
        // test, so the speaking flag is set and cleared inside one pump and
        // the pulse never runs. This fake holds each line for a real
        // duration on the fake clock so the animation actually plays.
        final state = HighLowGameState(
          totalPrompts: 3,
          agencyStage: stage,
          roundOrder: RoundOrder.blocked,
          audio: _LongVoiceAudio(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: HighLowScreen(gameState: state, ownsGameState: true),
          ),
        );
        await tester.pump(Duration.zero);

        Offset feetOf(CharacterArt art) => tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is CharacterSprite && w.art == art,
              ),
            )
            .bottomCenter;

        final piperSamples = <Offset>[];
        final clefSamples = <Offset>[];
        var sawSpeaking = false;
        for (var frame = 0; frame < 320; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          // Read off the widget that actually drives the pulse, so this
          // checks what a child sees rather than the game state's flag.
          if (find
              .byWidgetPredicate((w) => w is SpeakingPulse && w.speaking)
              .evaluate()
              .isNotEmpty) {
            sawSpeaking = true;
          }
          piperSamples.add(feetOf(CharacterArt.piper));
          clefSamples.add(feetOf(CharacterArt.clef));
        }
        expect(sawSpeaking, isTrue, reason: 'the intro must actually speak');

        for (final (name, samples) in [
          ('Piper', piperSamples),
          ('Clef', clefSamples),
        ]) {
          final settled = samples.last;
          for (var i = 0; i < samples.length; i++) {
            expect(
              (samples[i] - settled).distance,
              lessThan(2.0),
              reason:
                  '$name\'s feet jumped on frame $i to ${samples[i]} '
                  '(settled at $settled)',
            );
          }
          expect(
            samples.every((o) => o.dx > roomyViewport.width * 0.5),
            isTrue,
            reason: '$name was sampled on the left half of the screen',
          );
        }
        // Not disposed here: the screen owns it (ownsGameState: true).
      });
    }

    // The sighting itself: the jump came on a *correct tap* at Explore,
    // which is when the "found it" sparkle mounts inside the character's
    // Stack. The sparkle's own Stack (all children positioned) used to size
    // itself to its unbounded incoming constraints — an assert in debug, an
    // infinitely large character box in release. The speaking test above
    // never taps, so it never mounted the sparkle.
    testWidgets('a correct tap at Explore sparkles without moving either '
        'character', (tester) async {
      tester.view.physicalSize = roomyViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.explore,
        generator: PromptGenerator(random: Random(1)),
      );
      await tester.pumpWidget(
        MaterialApp(home: HighLowScreen(gameState: state, ownsGameState: true)),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1200));
      }
      await tester.pump(Duration.zero);

      Offset feetOf(CharacterArt art) => tester
          .getRect(
            find.byWidgetPredicate((w) => w is CharacterSprite && w.art == art),
          )
          .bottomCenter;
      final piperSettled = feetOf(CharacterArt.piper);
      final clefSettled = feetOf(CharacterArt.clef);

      var sawSparkle = false;
      // Four, not five: the fifth correct tap resolves the round.
      for (var tap = 1; tap <= 4; tap++) {
        state.tapInstrument(state.currentPrompt!.targetSide);
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (find.text('✨').evaluate().isNotEmpty) sawSparkle = true;
          expect(tester.takeException(), isNull, reason: 'tap $tap');
          for (final (name, art, settled) in [
            ('Piper', CharacterArt.piper, piperSettled),
            ('Clef', CharacterArt.clef, clefSettled),
          ]) {
            expect(
              (feetOf(art) - settled).distance,
              lessThan(2.0),
              reason: '$name\'s feet moved after correct tap $tap',
            );
          }
        }
      }
      expect(sawSparkle, isTrue, reason: 'the sparkle must actually mount');
    });
  });
}

/// Stands in for [AudioController] in the speaking regression test: voice
/// lines take a real amount of time (on the fake clock), everything else is
/// a no-op. Only the members the High/Low game state actually calls are
/// overridden; the rest fall through to [noSuchMethod] as null.
class _LongVoiceAudio implements AudioController {
  @override
  Future<void> playVoiceLineAndAwait(SpokenLine line) =>
      Future<void>.delayed(const Duration(milliseconds: 1500));

  @override
  Future<void> playVoiceLine(SpokenLine line) => Future<void>.value();

  @override
  Future<void> playAssetForScale(String path) => Future<void>.value();

  @override
  Future<void> playSfx(SfxType sfx) => Future<void>.value();

  @override
  void stopCurrentNote() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

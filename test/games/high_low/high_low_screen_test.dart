import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';

void main() {
  testWidgets('lays out cleanly on a tight landscape viewport without overflow '
      '(regression test for Trello card 46 — a FittedBox wrapping a Stack '
      'whose children are all Positioned silently collapses to zero width, '
      'which release builds render as garbled/misplaced content instead of '
      'throwing, so this needs an explicit check rather than eyeballing a '
      'screenshot)', (tester) async {
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

    // Advance past the postFrameCallback that starts the game and the
    // 2300ms gap _playCurrentPrompt waits between the two notes (Trello
    // card 57/58 — was 800ms, too short for the ~1.65s note samples). Not
    // pumpAndSettle — Clef and the glow/wiggle treatment use repeating
    // animations that never settle (same reason test/widget_test.dart
    // avoids it).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    // The last pump's frame rebuilds the status text with a new
    // ValueKey(status) (playing -> awaitingInput), which remounts its
    // Animate wrapper and schedules a fresh zero-duration startup Timer
    // (flutter_animate's `Animate._restart`) *during* that pump's own
    // frame — too late for that same call's `elapse()` to fire it. A bare
    // `pump()` (null duration) skips `elapse()` entirely and would never
    // fire it either, so this needs one more pump with an explicit
    // (if zero) duration to actually process it.
    await tester.pump(Duration.zero);

    expect(tester.takeException(), isNull);
    expect(find.byType(HighLowScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/app.dart';

void main() {
  // ProfileState/ProgressState/SkillState now await a real SharedPreferences
  // round-trip (Trello card 170) before this test's own flow proceeds — an
  // unmocked SharedPreferences.getInstance() call never resolves in a plain
  // widget test, which silently stalls that await instead of throwing.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders the SongStone landing screen then the games grid', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EarTrainerApp());

    // The real first screen since profiles landed (Trello card 170) is
    // "who's playing?" — add a child and pick them to reach the rest of the
    // app the way a real launch does.
    expect(find.text("Who's playing?"), findsOneWidget);
    await tester.tap(find.text('Add a child'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test Child');
    await tester.tap(find.text('Add'));
    // Real SharedPreferences round-trips happen here (profile save, then
    // ProgressState/SkillState loading scoped to the new profile) — genuine
    // async work, not fake-clock timers, so this needs `runAsync` to
    // actually let it resolve rather than a plain `pump()`.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();
    // ignore: avoid_print

    // Pump past the longest animation delay in the app (800ms delay + 300ms
    // duration) so all flutter_animate Timers fire before the test ends.
    // We can't use pumpAndSettle because the Learning Path screen has a
    // repeating Ticker-based animation that never settles.
    await tester.pump(const Duration(milliseconds: 1200));

    // The app now opens on the branded SongStone landing screen, not
    // straight into the games grid — verify its section menu renders.
    expect(find.text('Playground'), findsOneWidget);
    expect(find.text('Learning Path'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);

    // Tapping "Games" should land on the bottom-nav shell's games grid.
    await tester.tap(find.text('Games'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Ear Training Games'), findsOneWidget);
    expect(find.text('Choose a game'), findsOneWidget);
  });
}

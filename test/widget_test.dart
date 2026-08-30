import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/app.dart';

void main() {
  testWidgets('App renders the SongStone landing screen then the games grid', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EarTrainerApp());
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

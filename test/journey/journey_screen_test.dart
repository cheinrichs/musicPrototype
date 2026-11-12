import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/journey/journey_screen.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Walks both celebrations through the dev shortcut, which celebrates the
/// child's stone without playing it — the flows are the same either way.
Future<void> run(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late JourneyState journey;

  setUp(() {
    devToolsEnabled = true;
    journey = JourneyState();
  });
  tearDown(() => devToolsEnabled = false);

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(844, 390) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: journey,
        child: const MaterialApp(home: JourneyScreen()),
      ),
    );
    // The opening pan: to the chest and back.
    await run(tester, const Duration(seconds: 4));
  }

  testWidgets('regular stone: waits for the tap, then the reward flies to '
      'the rail and the stone is done', (tester) async {
    await mount(tester);
    expect(find.byKey(const ValueKey('rail-songs')), findsNothing);

    await tester.tap(find.text('DEV: finish stone'));
    await run(tester, const Duration(seconds: 5));
    // Nothing moves on until the child taps the gift.
    expect(find.byKey(const ValueKey('gift')), findsOneWidget);
    expect(journey.current, 0);

    await tester.tap(find.byKey(const ValueKey('gift')));
    await run(tester, const Duration(seconds: 6));
    expect(journey.current, 1);
    expect(find.byKey(const ValueKey('rail-songs')), findsOneWidget);
    expect(find.byKey(const ValueKey('gift')), findsNothing);
  });

  testWidgets('milestone: the chest waits for the tap, then rewards go to '
      'the rail and the map, and a new chest is ahead', (tester) async {
    await mount(tester);
    await tester.tap(find.text('DEV: to milestone'));
    await run(tester, const Duration(seconds: 2));
    expect(journey.current, 4);

    await tester.tap(find.text('DEV: finish stone'));
    await run(tester, const Duration(seconds: 6));
    expect(journey.current, 4, reason: 'waiting for the chest to be tapped');

    await tester.tap(find.byKey(const ValueKey('chest')));
    await run(tester, const Duration(seconds: 10));
    expect(journey.current, 5);
    expect(journey.decorations, hasLength(1));
    expect(journey.chestStone, 9);
  });
}

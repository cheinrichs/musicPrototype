import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/rail_shell.dart';
import 'package:ear_trainer/journey/journey_art.dart';
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
        child: const MaterialApp(home: RailShell()),
      ),
    );
    // The opening pan: to the chest and back.
    await run(tester, const Duration(seconds: 4));
  }

  RailController rail(WidgetTester tester) => Provider.of<RailController>(
    tester.element(find.byType(JourneyScreen, skipOffstage: false)),
    listen: false,
  );

  testWidgets('the rail is the top level: four destinations, Journey '
      'selected on arrival', (tester) async {
    await mount(tester);
    for (final d in RailDestination.values) {
      expect(find.byKey(ValueKey('rail-${d.name}')), findsOneWidget);
    }
    expect(rail(tester).selected, RailDestination.journey);
    expect(find.byType(JourneyScreen), findsOneWidget);
    // A state pair: the page you are on is the rounded square, the rest
    // circles.
    bool square(RailDestination d) => tester
        .widget<RailIcon>(
          find.descendant(
            of: find.byKey(ValueKey('rail-${d.name}')),
            matching: find.byType(RailIcon),
          ),
        )
        .selected;
    expect(RailDestination.values.where(square), [RailDestination.journey]);

    await tester.tap(find.byKey(const ValueKey('rail-crafts')));
    // Past the icons' crossfade (the map's own loops never settle).
    await run(tester, const Duration(milliseconds: 500));
    expect(rail(tester).selected, RailDestination.crafts);
    expect(RailDestination.values.where(square), [RailDestination.crafts]);
  });

  testWidgets('regular stone: waits for the tap, then the reward flies to '
      'its destination on the rail and the stone is done', (tester) async {
    await mount(tester);
    await tester.tap(find.text('DEV: finish stone'));
    await run(tester, const Duration(seconds: 5));
    // Nothing moves on until the child taps the gift.
    expect(find.byKey(const ValueKey('gift')), findsOneWidget);
    expect(journey.current, 0);

    await tester.tap(find.byKey(const ValueKey('gift')));
    await run(tester, const Duration(seconds: 6));
    expect(journey.current, 1);
    // The first reward is a song: a note card, landing on Playground.
    expect(rail(tester).pulsesOf(RailDestination.playground), 1);
    expect(rail(tester).flights, isEmpty);
    expect(find.byKey(const ValueKey('gift')), findsNothing);
  });

  testWidgets('milestone: the chest waits for the tap, then rewards go to '
      'the rail and a decoration onto the map, and a new chest is ahead', (
    tester,
  ) async {
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

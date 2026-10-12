import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/dial_mode.dart';
import 'package:ear_trainer/ui/components/dev_setup_overlay.dart';

void main() {
  testWidgets(
    'lets a developer change agency stage / tier / round order, then confirms',
    (tester) async {
      final devSettings = DevSettingsState();
      var started = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<DevSettingsState>.value(
          value: devSettings,
          child: MaterialApp(
            home: Scaffold(
              body: DevSetupOverlay(onStart: () => started = true),
            ),
          ),
        ),
      );

      expect(find.text('Dev: agency setup'), findsOneWidget);
      expect(devSettings.agencyStage, AgencyStage.decide);

      await tester.tap(find.text('A0 · Observe'));
      await tester.pump();
      expect(devSettings.agencyStage, AgencyStage.observe);

      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(started, isTrue);
    },
  );

  testWidgets('fits the tightest landscape viewport without overflowing or '
      'scrolling — Trello card "Dev agency setup screen should fit without '
      'scrolling": the Round order row and Start button used to fall below '
      'the fold on an iPhone SE', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(1334, 750); // iPhone SE landscape

    await tester.pumpWidget(
      ChangeNotifierProvider<DevSettingsState>.value(
        value: DevSettingsState(),
        child: MaterialApp(
          home: Scaffold(body: DevSetupOverlay(onStart: () {})),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final startButton = tester.getRect(find.text('Start'));
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(startButton.bottom, lessThanOrEqualTo(viewportHeight));
  });

  testWidgets('the Rounds row sets the round-set length for the agency '
      'picked above it, and only that one (Trello card 196)', (tester) async {
    final devSettings = DevSettingsState();
    await tester.pumpWidget(
      ChangeNotifierProvider<DevSettingsState>.value(
        value: devSettings,
        child: MaterialApp(
          home: Scaffold(body: DevSetupOverlay(onStart: () {})),
        ),
      ),
    );
    String shown() =>
        tester.widget<Text>(find.byKey(const ValueKey('rounds-value'))).data!;

    expect(shown(), '5', reason: 'Decide by default: 5');
    await tester.tap(find.text('A0 · Observe'));
    await tester.pump();
    expect(shown(), '3', reason: 'Observe: 3');

    await tester.tap(find.byKey(const ValueKey('rounds-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rounds-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rounds-minus')));
    await tester.pump();
    expect(shown(), '4');
    expect(devSettings.roundSetLength.observe, 4);
    expect(devSettings.roundSetLength.explore, 4);
    expect(devSettings.roundSetLength.decide, 5);
  });

  testWidgets('the Dial toggle switches Loud or Quiet between the needle '
      'following every sound and only the child\'s taps (Trello card 208)', (
    tester,
  ) async {
    final devSettings = DevSettingsState();
    await tester.pumpWidget(
      ChangeNotifierProvider<DevSettingsState>.value(
        value: devSettings,
        child: MaterialApp(
          home: Scaffold(body: DevSetupOverlay(onStart: () {})),
        ),
      ),
    );
    expect(devSettings.dialMode, DialMode.everySound);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Taps'));
    await tester.pump();
    expect(devSettings.dialMode, DialMode.childTapsOnly);
  });

  test('RoundSetLength clamps to the range the dev screen offers', () {
    final s = DevSettingsState()..setRoundSetLength(AgencyStage.explore, 99);
    expect(s.roundSetLength.explore, 8);
    s.setRoundSetLength(AgencyStage.explore, 0);
    expect(s.roundSetLength.explore, 1);
  });

  testWidgets(
    'offers all eight tier chips, T1 through T8 — Trello card "Rebuild '
    'the tier ladder as eight tiers (2x2x2)": this screen only offered '
    'four before',
    (tester) async {
      final devSettings = DevSettingsState();
      await tester.pumpWidget(
        ChangeNotifierProvider<DevSettingsState>.value(
          value: devSettings,
          child: MaterialApp(
            home: Scaffold(body: DevSetupOverlay(onStart: () {})),
          ),
        ),
      );

      for (final label in ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('T8'));
      await tester.pump();
      expect(devSettings.conceptTier, ConceptTier.t8);
    },
  );

  testWidgets(
    'tiers the chosen agency stage cannot reach are shown but disabled — '
    'the gate must not let a developer build a state the product cannot '
    'reach (A1 stops short of T5; A0 holds at T1)',
    (tester) async {
      final devSettings = DevSettingsState();
      await tester.pumpWidget(
        ChangeNotifierProvider<DevSettingsState>.value(
          value: devSettings,
          child: MaterialApp(
            home: Scaffold(body: DevSetupOverlay(onStart: () {})),
          ),
        ),
      );

      bool enabled(String label) =>
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
              .onSelected !=
          null;

      for (final t in ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8']) {
        expect(enabled(t), isTrue, reason: '$t at the default (A2)');
      }

      await tester.tap(find.text('A1 · Explore'));
      await tester.pump();
      expect([
        for (final t in ['T1', 'T2', 'T3', 'T4']) enabled(t),
      ], everyElement(isTrue));
      expect([
        for (final t in ['T5', 'T6', 'T7', 'T8']) enabled(t),
      ], everyElement(isFalse));

      await tester.tap(find.text('A0 · Observe'));
      await tester.pump();
      expect(enabled('T1'), isTrue);
      expect([
        for (final t in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8']) enabled(t),
      ], everyElement(isFalse));
    },
  );
}

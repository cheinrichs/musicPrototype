import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
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
      expect(devSettings.agencyStage, AgencyStage.trigger);

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
}

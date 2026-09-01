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
}

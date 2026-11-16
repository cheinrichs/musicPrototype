// Renders the SongStone logo page as the player picker (1, 2, 3 and 5
// children), the setup quiz's picture page and the reading gate, at real
// device sizes — for a session that cannot drive the simulator.
//
// Off by default (it writes files). Run it with:
//
//   flutter test test/render/picker_render_test.dart --dart-define=RENDER_DIR=/some/dir
//
// Text renders in the test font (solid boxes).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/journey/journey_art.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/components/reading_gate.dart';
import 'package:ear_trainer/ui/screens/setup_quiz_screen.dart';
import 'package:ear_trainer/ui/screens/songstone_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

const _devices = {
  'se': Size(667, 375),
  'iphone14': Size(844, 390),
  'ipad': Size(1180, 820),
};

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
    await precacheImage(
      const AssetImage(JourneyArt.badges),
      tester.element(find.byKey(key)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final bytes = await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void main() {
  for (final MapEntry(key: device, value: size) in _devices.entries) {
    for (final n in [0, 1, 2, 5, 6]) {
      testWidgets('picker $device $n', (tester) async {
        SharedPreferences.setMockInitialValues({
          'profiles_v1': [
            for (var i = 0; i < n; i++)
              jsonEncode(
                Profile(
                  id: 'k$i',
                  name: ["Davis", "Delaney", "Ada", "Bo", "Cy", "Dee"][i],
                  avatar: i * 3,
                  ageBand: AgeBand.fourFive,
                ).toJson(),
              ),
          ],
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final profiles = ProfileState();
        await tester.runAsync(profiles.load);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: profiles),
                ChangeNotifierProvider(create: (_) => ProgressState()),
                ChangeNotifierProvider(create: (_) => SkillState()),
                ChangeNotifierProvider(create: (_) => JourneyState()),
              ],
              child: MaterialApp.router(
                routerConfig: GoRouter(
                  initialLocation: AppRoutes.profilePicker,
                  routes: [
                    GoRoute(
                      path: AppRoutes.profilePicker,
                      builder: (_, _) => const SongStoneHomeScreen(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await _capture(tester, key, 'picker_${device}_$n');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }, skip: _outDir.isEmpty);
    }

    testWidgets('quiz + gate $device', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          // Two avatars taken by siblings: hidden from the grid.
          child: const MaterialApp(home: SetupQuizScreen(takenAvatars: {0, 3})),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('quiz-name')), 'Davis');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz-next')));
      await tester.pump(const Duration(seconds: 1));
      await _capture(tester, key, 'quiz_picture_$device');
      await tester.tap(find.byKey(const ValueKey('quiz-next')));
      await tester.pump(const Duration(seconds: 1));
      await _capture(tester, key, 'quiz_drag_$device');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(
            home: ReadingGate(
              puzzle: ReadingGatePuzzle(
                targets: [42, 52, 96],
                grid: [50, 42, 51, 96, 52, 92, 30, 61, 77],
              ),
            ),
          ),
        ),
      );
      await _capture(tester, key, 'gate_$device');
    }, skip: _outDir.isEmpty);
  }
}

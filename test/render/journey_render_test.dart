// Renders the Journey's two celebrations, beat by beat, to PNG files at
// real device sizes — for a session that cannot drive the simulator.
//
// Off by default (it writes files). Run it with:
//
//   flutter test test/render/journey_render_test.dart --dart-define=RENDER_DIR=/some/dir
//
// Text renders in the test font (solid boxes).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/rail_shell.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

const _devices = {
  'iphone14': (
    Size(844, 390),
    EdgeInsets.only(left: 47, right: 47, bottom: 21),
  ),
  'ipad': (Size(1180, 820), EdgeInsets.only(bottom: 20)),
};

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  final bytes = await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

Future<void> _run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => devToolsEnabled = true);
  tearDown(() => devToolsEnabled = false);

  for (final MapEntry(key: device, value: (size, insets)) in _devices.entries) {
    testWidgets('journey_$device', skip: _outDir.isEmpty, (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        left: insets.left,
        right: insets.right,
        bottom: insets.bottom,
      );
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final journey = JourneyState();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: journey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(key: boundary, child: const RailShell()),
          ),
        ),
      );
      Future<void> shot(String n) => _capture(tester, boundary, '${device}_$n');

      await _run(tester, 1400);
      await shot('01_open_panning_to_chest');
      await _run(tester, 3000);
      await shot('02_settled_on_child');

      // Regular stone.
      await tester.tap(find.text('DEV: finish stone'));
      await _run(tester, 1200);
      await shot('03_speaking');
      await _run(tester, 2500);
      await shot('04_gift_waiting');
      await tester.tap(find.byKey(const ValueKey('gift')));
      await _run(tester, 900);
      await shot('05_gift_open_reward_out');
      await _run(tester, 1400);
      await shot('06_reward_flying');
      await _run(tester, 3000);
      await shot('07_back_on_path_arrow');

      // Milestone.
      await tester.tap(find.text('DEV: to milestone'));
      await _run(tester, 1500);
      await tester.tap(find.text('DEV: finish stone'));
      await _run(tester, 3200);
      await shot('08_chest_on_map');
      await _run(tester, 1500);
      await shot('09_chest_awake_waiting');
      await tester.tap(find.byKey(const ValueKey('chest')));
      await _run(tester, 1200);
      await shot('10_chest_open_presents');
      await _run(tester, 1100);
      await shot('11_presents_flying');
      await _run(tester, 4100);
      await shot('12_new_chest_ahead');
      await _run(tester, 3000);
      await shot('13_back_on_path');
    });
  }
}

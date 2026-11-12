// Renders the Games screen (the adult view: every game) to PNG files.
//
//   flutter test test/render/games_screen_render_test.dart --dart-define=RENDER_DIR=/some/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/ui/screens/home_screen.dart';
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

void main() {
  for (final MapEntry(key: device, value: (size, insets)) in _devices.entries) {
    testWidgets('games_$device', skip: _outDir.isEmpty, (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        left: insets.left,
        right: insets.right,
        bottom: insets.bottom,
      );
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: boundary, child: const HomeScreen()),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _capture(tester, boundary, 'games_$device');
    });
  }
}

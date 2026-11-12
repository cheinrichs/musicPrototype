// Renders map decorations at rest and mid-reaction to PNG files.
//
//   flutter test test/render/decorations_render_test.dart --dart-define=RENDER_DIR=/some/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/journey/map_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

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
  testWidgets('decorations', skip: _outDir.isEmpty, (tester) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    const names = [
      'acorn',
      'bluebells',
      'daisy',
      'mushroom',
      'pine_cone',
      'frog',
      'chipmunk',
      'bluebird',
      'ladybird',
      'snail',
      'butterfly',
      'dragonfly',
    ];
    Future<void> row(List<String> ns, String file, List<int> atMs) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: const Color(0xFF6B8E4E),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final n in ns)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 140, 8, 20),
                        child: MapDecoration(
                          key: ValueKey(n),
                          name: n,
                          size: 160,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await _capture(tester, boundary, '${file}_rest');
      for (final n in ns) {
        await tester.tap(find.byKey(ValueKey(n)));
      }
      var t = 0;
      for (final ms in atMs) {
        await tester.pump(Duration(milliseconds: ms - t));
        t = ms;
        await _capture(tester, boundary, '${file}_${ms}ms');
      }
      await tester.pump(const Duration(seconds: 2));
    }

    await row(names.sublist(0, 4), 'objects_a', [100, 300, 450]);
    await row(names.sublist(4, 8), 'mixed_b', [100, 250, 450]);
    await row(names.sublist(8, 12), 'creatures_c', [100, 300, 500]);
  });
}

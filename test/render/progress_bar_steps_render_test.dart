// Renders the round-set bar at every step of a 3-, 4- and 5-round set at
// its real top-row length on an SE, to judge whether one step reads as a
// change (Trello card 216: a third-length bar shrinks every increment, and
// the five-round set is the one at risk).
//
//   flutter test test/render/progress_bar_steps_render_test.dart --dart-define=RENDER_DIR=/some/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_header.dart';
import 'package:ear_trainer/ui/components/round_set_progress_bar.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

void main() {
  testWidgets('progress_bar_steps', skip: _outDir.isEmpty, (tester) async {
    // The SE's row: the screen less GameScreenLayout's side padding.
    final barWidth = HighLowHeader.barWidthFor(667 - 2 * 24);
    tester.view.physicalSize = const Size(1200, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFF6E8F4E),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final n in [3, 4, 5])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          for (var step = 0; step <= n; step++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: barWidth,
                                child: RoundSetProgressBar(progress: step / n),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final bytes = await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$_outDir/progress_bar_steps.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  });
}

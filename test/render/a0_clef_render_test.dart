// A0's big Clef on the bottom platform (card 222), at device size, so it
// can be judged whether the platforms "mostly disappear" behind her.
//
//   flutter test test/render/a0_clef_render_test.dart --dart-define=RENDER_DIR=/some/dir
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The iPhone 17 measured 62/0/62/20; with Trello 226 the side without the
  // island keeps only a 16 pt corner margin.
  const cases = {
    'iphone17_island_left': (Size(874, 402), [62.0, 16.0, 20.0]),
    'iphone17_island_right': (Size(874, 402), [16.0, 62.0, 20.0]),
    'iphone17_orientation_unknown': (Size(874, 402), [62.0, 62.0, 20.0]),
    'se': (Size(667, 375), [0.0, 0.0, 0.0]),
  };
  for (final MapEntry(key: name, value: (size, inset)) in cases.entries) {
    testWidgets('a0_$name', skip: _outDir.isEmpty, (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = FakeViewPadding(
        left: inset[0] * 3,
        right: inset[1] * 3,
        bottom: inset[2] * 3,
      );
      addTearDown(tester.view.reset);
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.observe,
        generator: PromptGenerator(random: Random(1)),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: HighLowScreen(gameState: state),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1200));
      }
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      final bytes = await tester.runAsync(() async {
        final r =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await r.toImage(pixelRatio: 3);
        return (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      });
      File('$_outDir/a0_$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
      state.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

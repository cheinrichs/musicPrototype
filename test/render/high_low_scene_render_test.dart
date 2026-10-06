// Renders the High/Low scene to PNG files at real phone sizes, so a session
// that cannot drive the simulator can still look at the composition.
//
// Off by default (it writes files). Run it with:
//
//   flutter test test/render/high_low_scene_render_test.dart --dart-define=RENDER_DIR=/some/dir
//
// Text renders in the test font (solid boxes), so judge where the caption
// plate sits, not how its words look. Everything else — the tree, the
// stumps, the instruments and the characters — is the real art at its real
// size and position.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/round_order.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

/// Real landscape phones, with the notch's side insets where there is one.
const _phones = {
  'se': (Size(667, 375), EdgeInsets.zero),
  'iphone14': (Size(844, 390), EdgeInsets.symmetric(horizontal: 47)),
  'promax': (Size(932, 430), EdgeInsets.symmetric(horizontal: 59)),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final phone in _phones.entries) {
    for (final stage in AgencyStage.values) {
      // One round of each pole, so both slots (and both askers) get drawn;
      // the two seeds give different instrument pairs.
      for (final (seed, wantLow) in [(1, false), (2, true)]) {
        final pole = wantLow ? 'low' : 'high';
        final name = '${phone.key}_${stage.name}_$pole';
        testWidgets(name, skip: _outDir.isEmpty, (tester) async {
          final (size, insets) = phone.value;
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2;
          tester.view.padding = FakeViewPadding(
            left: insets.left * 2,
            right: insets.right * 2,
          );
          addTearDown(tester.view.reset);

          final state = HighLowGameState(
            totalPrompts: 10,
            agencyStage: stage,
            roundOrder: RoundOrder.mixed,
            generator: PromptGenerator(random: Random(seed)),
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
          await tester.pump();
          Future<void> finishIntro() async {
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 1200));
            }
          }

          await finishIntro();
          // Skip rounds until this one asks about the wanted pole.
          for (var i = 0; i < 9; i++) {
            if (state.targetCharacterIsPiper == wantLow) break;
            state.escape();
            await tester.pump();
            await finishIntro();
          }
          expect(state.targetCharacterIsPiper, wantLow);

          // Decode every image for real, then let the frame pick them up.
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              final image = (element.widget as Image).image;
              await precacheImage(image, element);
            }
          });
          await tester.pump();

          final bytes = await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List();
          });
          File('$_outDir/$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!);
          state.dispose();
        });
      }
    }
  }
}

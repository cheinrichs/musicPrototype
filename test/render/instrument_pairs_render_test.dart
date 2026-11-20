// Renders a High/Low round with a CHOSEN instrument on both stumps, so how
// each instrument sits on its stump can be judged one instrument at a time
// (2026-11-20: the xylophone floated above its stump on Cooper's device).
//
// Off by default (it writes files). Run it with:
//
//   flutter test test/render/instrument_pairs_render_test.dart --dart-define=RENDER_DIR=/some/dir
//
// The phone is Cooper's: 874 x 402 points (his screenshots are 2622 x 1206
// at 3x), with the insets measured on that class of device.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/models/high_low_prompt.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

/// Every round puts [instrument] on both stumps, a fifth apart.
class _OneInstrument extends PromptGenerator {
  final HighLowInstrument instrument;
  _OneInstrument(this.instrument) : super(random: Random(1));

  @override
  HighLowPrompt generatePrompt({
    required int promptNumber,
    required ConceptTier tier,
    required PitchDirection targetDirection,
  }) {
    final midis = instrument.availableMidis;
    final low = midis[midis.length ~/ 2 - 4];
    return HighLowPrompt(
      firstMidi: low,
      secondMidi: low + 7,
      firstInstrument: instrument,
      secondInstrument: instrument,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final instrument in [
    HighLowInstrument.xylophone,
    HighLowInstrument.trumpet,
    HighLowInstrument.flute,
    HighLowInstrument.bells,
    HighLowInstrument.violin,
    HighLowInstrument.guitar,
  ]) {
    final name = 'pair_${instrument.name}';
    testWidgets(name, skip: _outDir.isEmpty, (tester) async {
      tester.view.physicalSize = const Size(874, 402) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(
        left: 62 * 3,
        right: 62 * 3,
        bottom: 20 * 3,
      );
      addTearDown(tester.view.reset);
      HighLowInstrument.trialsEnabled = true;
      addTearDown(() => HighLowInstrument.trialsEnabled = false);

      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.decide,
        generator: _OneInstrument(instrument),
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
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
      final bytes = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('$_outDir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      state.dispose();
    });
  }
}

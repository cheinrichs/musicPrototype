// Renders the Loud or Quiet scene to PNG files at real phone sizes, so a
// session that cannot drive the simulator can still look at the dial, the
// needle on its hub, and where everything sits.
//
// Off by default (it writes files). Run it with:
//
//   flutter test test/render/loud_quiet_scene_render_test.dart --dart-define=RENDER_DIR=/some/dir
//
// Text renders in the test font (solid boxes); everything else is the real
// art at its real size and position.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/games/loud_quiet/screens/loud_quiet_screen.dart';
import 'package:ear_trainer/games/loud_quiet/state/loud_quiet_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

const _phones = {
  'se': (Size(667, 375), EdgeInsets.zero),
  'iphone14': (Size(844, 390), EdgeInsets.symmetric(horizontal: 47)),
  'promax': (Size(932, 430), EdgeInsets.symmetric(horizontal: 59)),
};

class _SilentAudio implements AudioController {
  @override
  Future<void> playAssetForScale(String path, {double volume = 1.0}) async {}

  @override
  Future<void> playVoiceLineAndAwait(SpokenLine line) async {}

  @override
  Future<void> playSfx(SfxType sfx) async {}

  @override
  void stopCurrentNote() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

Future<void> _frames(WidgetTester tester, Duration d) async {
  for (var f = 0; f < d.inMilliseconds ~/ 16; f++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // What each picture shows, and what the child did to get there.
  final scenes =
      <
        String,
        (AgencyStage, Future<void> Function(LoudQuietGameState, WidgetTester))
      >{
        'observe_rest': (AgencyStage.observe, (s, t) async {}),
        'observe_loud': (
          AgencyStage.observe,
          (s, t) async => s.tapInstrument(s.currentRound!.loudSide),
        ),
        'observe_quiet': (
          AgencyStage.observe,
          (s, t) async {
            s.tapInstrument(s.currentRound!.loudSide);
            await _frames(t, const Duration(milliseconds: 600));
            s.tapInstrument(1 - s.currentRound!.loudSide);
          },
        ),
        'explore_sparkles': (
          AgencyStage.explore,
          (s, t) async {
            for (var i = 0; i < 3; i++) {
              s.tapInstrument(s.currentRound!.targetSide);
            }
          },
        ),
        'decide_slot': (AgencyStage.decide, (s, t) async {}),
        'decide_landed': (
          AgencyStage.decide,
          (s, t) async => s.dropInstrument(s.currentRound!.targetSide),
        ),
      };

  for (final phone in _phones.keys) {
    for (final scene in scenes.entries) {
      final name = '${phone}_lq_${scene.key}';
      testWidgets(name, skip: _outDir.isEmpty, (tester) async {
        final (size, insets) = _phones[phone]!;
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.view.padding = FakeViewPadding(
          left: insets.left * 2,
          right: insets.right * 2,
        );
        addTearDown(tester.view.reset);
        final (stage, act) = scene.value;
        final state = LoudQuietGameState(
          audio: _SilentAudio(),
          random: Random(1),
          agencyStage: stage,
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: LoudQuietScreen(gameState: state),
            ),
          ),
        );
        await _frames(tester, const Duration(milliseconds: 4800));
        await act(state, tester);
        await _frames(tester, const Duration(milliseconds: 700));
        await _capture(tester, boundary, name);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        state.dispose();
      });
    }
  }
}

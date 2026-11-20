// Filmstrips of Journey travel (Trello 227): Piper walking, Clef hopping
// and the pin arcing across one stone gap, sampled through the trip, so
// the gait, its phase and the frames' horizontal registration can be
// judged without a device.
//
//   flutter test test/render/journey_travel_render_test.dart --dart-define=RENDER_DIR=/some/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/games/high_low/widgets/character_art.dart';
import 'package:ear_trainer/games/high_low/widgets/mouth_frames.dart';
import 'package:ear_trainer/journey/journey_travel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDir = String.fromEnvironment('RENDER_DIR');

void main() {
  for (final who in ['piper', 'clef', 'pin']) {
    testWidgets('travel_$who', skip: _outDir.isEmpty, (tester) async {
      tester.view.physicalSize = const Size(700, 260) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const h = 160.0;
      final art = who == 'clef' ? CharacterArt.clef : CharacterArt.piper;
      final w = who == 'pin'
          ? 70.0
          : art.frameSize.width * h / art.frameSize.height;
      Rect at(double x) => Rect.fromLTWH(x - w / 2, 230 - h, w, h);
      Widget app(double x) => MaterialApp(
        home: Container(
          color: const Color(0xFF9DB86A),
          child: Stack(
            children: [
              Traveller(
                key: const ValueKey('t'),
                rect: at(x),
                duration: const Duration(milliseconds: 1100),
                gait: who == 'piper'
                    ? Gait.piperWalk
                    : who == 'clef'
                    ? Gait.clefHop
                    : null,
                arc: who == 'pin' ? 0.15 : 0,
                bodyHeight: who == 'clef'
                    ? h * CharacterArt.clefGrowth * 719 / 723 * 0.73 / 0.63
                    : h,
                rest: who == 'pin'
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      )
                    : CharacterSprite(
                        art: art,
                        pose: CharacterPose.speaking,
                        mouth: MouthFrame.closed,
                        height: h,
                      ),
              ),
            ],
          ),
        ),
      );
      final boundary = GlobalKey();
      Widget wrap(double x) => RepaintBoundary(key: boundary, child: app(x));
      await tester.pumpWidget(wrap(120));
      await tester.runAsync(() async {
        for (final a in [
          'piper/piper_H_move_x3.png',
          'clef/clef_H_move_x3.png',
        ]) {
          await precacheImage(
            AssetImage('assets/images/characters/$a'),
            tester.element(find.byType(Stack).first),
          );
        }
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      Future<void> shot(String name) async {
        await tester.pump();
        final bytes = await tester.runAsync(() async {
          final r =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await r.toImage(pixelRatio: 1);
          return (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        });
        File('$_outDir/travel_${who}_$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
      }

      await shot('rest_before');
      await tester.pumpWidget(wrap(560));
      for (var i = 0; i <= 14; i++) {
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
          final image = await r.toImage(pixelRatio: 1);
          return (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        });
        File('$_outDir/travel_${who}_${i.toString().padLeft(2, '0')}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
        await tester.pump(const Duration(milliseconds: 90));
      }
      await tester.pumpAndSettle();
      await shot('rest_after');
    });
  }
}

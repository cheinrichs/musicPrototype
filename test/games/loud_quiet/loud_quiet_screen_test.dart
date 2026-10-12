import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_layout.dart';
import 'package:ear_trainer/games/loud_quiet/screens/loud_quiet_screen.dart';
import 'package:ear_trainer/games/loud_quiet/state/loud_quiet_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/game_status.dart';

class _QuietAudio implements AudioController {
  int notes = 0;

  @override
  Future<void> playAssetForScale(String path, {double volume = 1.0}) async {
    notes++;
  }

  @override
  Future<void> playVoiceLineAndAwait(SpokenLine line) async {}

  @override
  Future<void> playSfx(SfxType sfx) async {}

  @override
  void stopCurrentNote() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const viewports = {
    'iPhone SE': Size(667, 375),
    'iPhone 14': Size(844, 390),
    'iPhone 17': Size(874, 402),
    'Pro Max': Size(932, 430),
  };

  late _QuietAudio audio;
  late LoudQuietGameState game;

  Future<void> mount(
    WidgetTester tester, {
    AgencyStage stage = AgencyStage.observe,
    Size viewport = const Size(667, 375),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    audio = _QuietAudio();
    game = LoudQuietGameState(
      audio: audio,
      random: math.Random(4),
      agencyStage: stage,
    );
    addTearDown(game.dispose);
    final router = GoRouter(
      initialLocation: '/game',
      routes: [
        GoRoute(
          path: '/game',
          builder: (context, state) => LoudQuietScreen(gameState: game),
        ),
        GoRoute(
          path: AppRoutes.reward,
          builder: (context, state) => const Text('reward'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('home'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Past the post-frame start and both opening sounds, in frames, so the
    // animations actually run.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Unmounts and lets the last timers run out, so none is left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  double needleDegrees(WidgetTester tester) {
    final rotate = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('needle')),
        matching: find.byType(Transform),
      ),
    );
    final m = rotate.transform.storage;
    return math.atan2(m[1], m[0]) * 180 / math.pi;
  }

  for (final entry in viewports.entries) {
    testWidgets('lays out without overflow on ${entry.key}', (tester) async {
      await mount(tester, viewport: entry.value);
      expect(tester.takeException(), isNull);
      expect(game.status, GameStatus.awaitingInput);
      expect(find.byKey(const ValueKey('lq-piper')), findsOneWidget);
      expect(find.byKey(const ValueKey('lq-clef')), findsOneWidget);
      expect(find.byKey(const ValueKey('lq-instrument-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('lq-instrument-1')), findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets('no Listen Again button (card 195)', (tester) async {
    await mount(tester);
    expect(find.text('Listen Again'), findsNothing);
    expect(find.text('Listen again'), findsNothing);
    await finish(tester);
  });

  testWidgets('the needle rests straight up through the opening sounds, and '
      'swings to the side the child taps', (tester) async {
    await mount(tester);
    expect(needleDegrees(tester), closeTo(0, 0.01));
    final loud = game.currentRound!.loudSide;
    await tester.tap(find.byKey(ValueKey('lq-instrument-$loud')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(needleDegrees(tester), closeTo(LoudQuietLayout.sweepDegrees, 0.5));
    await tester.tap(find.byKey(ValueKey('lq-instrument-${1 - loud}')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(needleDegrees(tester), closeTo(-LoudQuietLayout.sweepDegrees, 0.5));
    await finish(tester);
  });

  testWidgets('tapping a character replays the round', (tester) async {
    await mount(tester);
    final before = audio.notes;
    await tester.tap(find.byKey(const ValueKey('lq-piper')));
    await tester.pump();
    expect(audio.notes, before + 1);
    expect(game.status, GameStatus.playing);
    await tester.tap(find.byKey(const ValueKey('lq-clef')));
    await tester.pump();
    expect(audio.notes, before + 2);
    await finish(tester);
  });

  testWidgets('Observe: the arrow appears once both are heard, and moves on', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byTooltip('Tap when ready'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lq-instrument-0')));
    await tester.tap(find.byKey(const ValueKey('lq-instrument-1')));
    await tester.pump();
    expect(find.byTooltip('Tap when ready'), findsOneWidget);
    await tester.tap(find.byTooltip('Tap when ready'));
    await tester.pump();
    expect(game.currentPromptIndex, 1);
    await finish(tester);
  });

  testWidgets('Decide: dragging the asked-for instrument to the slot lands '
      'it', (tester) async {
    await mount(tester, stage: AgencyStage.decide);
    final target = game.currentRound!.targetSide;
    final layout = LoudQuietLayout(const Size(667, 375));
    final slot = layout
        .slotRect(layout.slotPlatformFor(loud: game.asksLoud))
        .center;
    final from = tester.getCenter(
      find.byKey(ValueKey('lq-instrument-$target')),
    );
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 20; i++) {
      await gesture.moveTo(Offset.lerp(from, slot, i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(game.drop, LoudQuietDrop.correct);
    expect(game.correctCount, 1);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('finishing the session goes to the reward screen', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 0; i < game.totalPrompts; i++) {
      game.escape();
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('reward'), findsOneWidget);
    await finish(tester);
  });
}

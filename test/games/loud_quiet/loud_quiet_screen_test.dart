import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/sfx_type.dart';
import 'package:ear_trainer/audio/spoken_line.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_slot.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_layout.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:ear_trainer/games/loud_quiet/screens/loud_quiet_screen.dart';
import 'package:ear_trainer/games/loud_quiet/state/loud_quiet_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/game_status.dart';
import 'package:ear_trainer/ui/components/drop_snap.dart';

class _QuietAudio implements AudioController {
  int notes = 0;

  /// Audio can't say here, so the game uses its fallback length.
  @override
  Future<Duration?> noteLength(String path) async => null;

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
    // Past the post-frame start, both opening sounds and the needle coming
    // home, in frames, so the animations actually run.
    for (var i = 0; i < 340; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // A real-time wait for the art to decode: an image not yet sized takes
    // no touches, so a drag on it would never start (as in High vs Low's
    // tests).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  /// Unmounts and lets the last timers run out, so none is left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Long enough for a next round's whole opening, which a correct Decide
    // drop starts only after its instrument has played (card 208).
    await tester.pump(const Duration(seconds: 10));
  }

  double needleDegrees(WidgetTester tester) {
    final rotate = tester.widget<Transform>(
      find.byKey(const ValueKey('needle')),
    );
    final m = rotate.transform.storage;
    return math.atan2(m[1], m[0]) * 180 / math.pi;
  }

  Future<void> frames(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
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

  testWidgets('the needle is home at rest — the quiet end — once the opening '
      'sounds have played, and every tap on the loud one swings it out and '
      'back, four taps four swings (card 208)', (tester) async {
    await mount(tester);
    const rest = LoudQuietLayout.restDegrees;
    expect(needleDegrees(tester), closeTo(rest, 0.5));
    final loud = game.currentRound!.loudSide;
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(ValueKey('lq-instrument-$loud')));
      await frames(tester, 300);
      expect(
        needleDegrees(tester),
        greaterThan(LoudQuietLayout.needleDegrees(1) - 12),
        reason: 'tap ${i + 1} swings out to loud',
      );
      await frames(tester, 2000);
      expect(needleDegrees(tester), closeTo(rest, 0.5), reason: 'and home');
    }
    await finish(tester);
  });

  testWidgets('a tap mid-gesture restarts from where the needle is — no '
      'jump home, no queue', (tester) async {
    await mount(tester);
    final loud = game.currentRound!.loudSide;
    await tester.tap(find.byKey(ValueKey('lq-instrument-$loud')));
    await frames(tester, 600);
    final before = needleDegrees(tester);
    await tester.tap(find.byKey(ValueKey('lq-instrument-${1 - loud}')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(needleDegrees(tester), closeTo(before, 6));
    await frames(tester, 300);
    expect(
      needleDegrees(tester),
      closeTo(
        LoudQuietLayout.needleDegrees(
          LoudQuietRound.needlePosition(game.currentRound!.quietGain),
        ),
        6,
      ),
      reason: 'now at the quiet sound\'s level',
    );
    await finish(tester);
  });

  testWidgets('Decide: a lock sits over the knob; a wrong drop leaves it '
      'shut, the right one opens it', (tester) async {
    await mount(tester, stage: AgencyStage.decide);
    expect(find.byKey(const ValueKey('dial-lock')), findsOneWidget);
    game.dropInstrument(1 - game.currentRound!.targetSide);
    await frames(tester, 300);
    expect(find.byKey(const ValueKey('dial-lock')), findsOneWidget);
    expect(game.dialLocked, isTrue);
    await frames(tester, 1500);
    game.dropInstrument(game.currentRound!.targetSide);
    await frames(tester, 900);
    expect(find.byKey(const ValueKey('dial-lock')), findsNothing);
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

  testWidgets('Decide: held low down, the instrument covering the slot '
      'lands — the drop is judged by where the instrument is, not where the '
      'finger is (card 221)', (tester) async {
    await mount(tester, stage: AgencyStage.decide);
    final target = game.currentRound!.targetSide;
    final layout = LoudQuietLayout(const Size(667, 375));
    final slot = layout
        .slotRect(layout.slotPlatformFor(loud: game.asksLoud))
        .center;
    final box = tester.getRect(find.byKey(ValueKey('lq-instrument-$target')));
    // Grabbed near its base, as a small child grabs a tall instrument.
    final grip = Offset(0, box.height * 0.4);
    final from = box.center + grip;
    // The finger ends a grip's height below the slot; the instrument is on it.
    final to = slot + grip;
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 20; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(game.drop, LoudQuietDrop.correct);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finish(tester);
  });

  // Card 221: held anywhere on the instrument, released anywhere around the
  // slot — it lands exactly when the slot lit up, and when it doesn't, the
  // miss is recorded with its distance.
  group('card 221: where a drop lands', () {
    Future<({bool lit, bool landed, List<double> misses})> release(
      WidgetTester tester, {
      required Offset grip,
      required Offset Function(Rect slot, double radius) at,
    }) async {
      await mount(tester, stage: AgencyStage.decide);
      final target = game.currentRound!.targetSide;
      final layout = LoudQuietLayout(const Size(667, 375));
      final slot = layout.slotRect(layout.slotPlatformFor(loud: game.asksLoud));
      final box = tester.getRect(find.byKey(ValueKey('lq-instrument-$target')));
      final radius = DropSnap.radiusFor(box.width);
      // Held [grip] (a fraction of its size) from its centre, so the finger
      // ends that far from where the instrument's centre lands.
      final g = Offset(grip.dx * box.width, grip.dy * box.height);
      final from = box.center + g;
      final to = at(slot, radius) + g;
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      final lit =
          tester
              .widget<OrderingSlot>(find.byKey(const ValueKey('lq-slot')))
              .state ==
          SlotState.hovering;
      await gesture.up();
      await tester.pump();
      final result = (
        lit: lit,
        landed: game.drop == LoudQuietDrop.correct,
        misses: game.missedDrops,
      );
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finish(tester);
      return result;
    }

    // On the drawn art: the tall instruments are narrower than their square
    // box, and a touch in the empty margin beside one picks nothing up.
    const grips = {
      'by the middle': Offset.zero,
      'by the base': Offset(0, 0.4),
      'by the top': Offset(0, -0.4),
      'low and off-centre': Offset(0.12, 0.3),
      'high and off-centre': Offset(-0.12, -0.3),
    };
    for (final MapEntry(key: name, value: grip) in grips.entries) {
      testWidgets('held $name, centred on the slot: lit, and lands', (
        tester,
      ) async {
        final r = await release(tester, grip: grip, at: (s, _) => s.center);
        expect(r.lit, isTrue);
        expect(r.landed, isTrue);
        expect(r.misses, isEmpty);
      });
    }

    final near = <String, Offset Function(Rect, double)>{
      'just above it': (s, r) => s.topCenter - Offset(0, r * 0.9),
      'just below it': (s, r) => s.bottomCenter + Offset(0, r * 0.9),
      'just left of it': (s, r) => s.centerLeft - Offset(r * 0.9, 0),
      'just right of it': (s, r) => s.centerRight + Offset(r * 0.9, 0),
    };
    for (final MapEntry(key: name, value: at) in near.entries) {
      testWidgets('held by the base, released $name: lit, and lands', (
        tester,
      ) async {
        final r = await release(tester, grip: const Offset(0, 0.4), at: at);
        expect(r.lit, isTrue);
        expect(r.landed, isTrue);
      });
    }

    final far = <String, Offset Function(Rect, double)>{
      'above it': (s, r) => s.topCenter - Offset(0, r * 1.2),
      'left of it': (s, r) => s.centerLeft - Offset(r * 1.2, 0),
    };
    for (final MapEntry(key: name, value: at) in far.entries) {
      testWidgets('released past the radius $name: never lit, never lands, '
          'and the miss is logged with its distance', (tester) async {
        final r = await release(tester, grip: const Offset(0, 0.4), at: at);
        expect(r.lit, isFalse);
        expect(r.landed, isFalse);
        expect(r.misses, hasLength(1));
        expect(r.misses.single, greaterThan(0));
      });
    }
  });

  double barFill(WidgetTester tester) {
    final bar = tester.getSize(
      find.byKey(const ValueKey('round-set-progress')),
    );
    final fill = tester.getSize(
      find.byKey(const ValueKey('round-set-progress-fill')),
    );
    return fill.width / (bar.width - 4);
  }

  testWidgets('the progress bar fills a step per round, and when full the '
      'set really ends — the games screen after a beat, never a silent '
      'restart or a reward screen (card 196)', (tester) async {
    await mount(tester);
    expect(game.totalPrompts, 3, reason: 'Observe: the shared setting');
    expect(barFill(tester), closeTo(0, 0.01));
    game.escape();
    await frames(tester, 600);
    expect(barFill(tester), closeTo(1 / 3, 0.02));
    game.escape();
    game.escape();
    await frames(tester, 600);
    expect(barFill(tester), closeTo(1, 0.02));
    expect(find.text('home'), findsNothing, reason: 'shown full first');
    await frames(tester, 400);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('reward'), findsNothing);
    await finish(tester);
  });

  testWidgets('the close sits on its own solid plate beside the bar (card '
      '216), the whole plate takes the tap, and leaving logs its own event '
      '(card 196)', (tester) async {
    await mount(tester);
    final close = tester.getRect(find.byKey(const ValueKey('close-plate')));
    final bar = tester.getRect(
      find.byKey(const ValueKey('round-set-progress')),
    );
    expect(close.width, greaterThanOrEqualTo(44));
    expect(close.height, greaterThanOrEqualTo(44));
    expect(bar.width, lessThan(667 * 0.3), reason: 'a third of what it was');
    expect((close.center.dy - bar.center.dy).abs(), lessThan(4));
    // The whole of the close takes a tap, corner to corner.
    for (final p in [
      close.center,
      close.topLeft + const Offset(3, 3),
      close.bottomRight - const Offset(3, 3),
    ]) {
      final hit = tester.hitTestOnBinding(p);
      expect(
        hit.path.any(
          (e) =>
              e.target is RenderPointerListener ||
              e.target.runtimeType.toString().contains('Gesture'),
        ),
        isTrue,
        reason: 'tap at $p reaches the close',
      );
    }
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump();
    expect(find.text('home'), findsOneWidget, reason: 'the tap left');
    expect(game.records, hasLength(1));
    expect(game.records.single.leftSet, isTrue);
    expect(game.records.single.skipped, isFalse);
    expect(find.text('home'), findsOneWidget);
    await finish(tester);
  });
}

// Opens ONE High/Low scene directly, for simulator screenshots — no home
// screen, no dev gate, no tapping. Not part of the app: it is a separate
// entry point (`-t tool/screenshot_main.dart`) and nothing imports it.
//
// The scene is chosen at *launch* from the file /tmp/hl_scene (write the scene
// name there, then `xcrun simctl launch`), so one build serves every scene.
//
// Scenes: a0, a0arrow, a1, a2, a2correct, a2wrong, order2, order3, order2done.
// The scripted ones (arrow, correct/wrong drop, placed instruments) wait for
// the round's intro to finish, then act.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ear_trainer/app/app.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/audio/audio_controller.dart';
import 'package:ear_trainer/audio/voice_envelope.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_game_state.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_screen.dart';
import 'package:ear_trainer/games/high_low/screens/high_low_screen.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  devToolsEnabled = false;
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  try {
    await AudioController.instance.init();
    AudioController.instance.preloadAll(
      highLowAssetPaths: [
        for (final i in HighLowInstrument.values) ...i.allAssetPaths,
      ],
    );
  } catch (e) {
    debugPrint('Audio unavailable: $e');
  }
  unawaited(VoiceEnvelopeLibrary.preload());

  // The simulator shares the Mac's filesystem, and launch-time environment
  // variables did not reach the app, so the scene is read from a file.
  var scene = 'a2';
  try {
    scene = File('/tmp/hl_scene').readAsStringSync().trim();
  } catch (_) {}
  final Widget screen;
  if (scene.startsWith('order')) {
    final tier = scene.startsWith('order3') ? ConceptTier.t5 : ConceptTier.t1;
    final state = OrderingGameState(tier: tier);
    screen = OrderingScreen(tier: tier, state: state);
    if (scene.endsWith('done')) {
      // Two placed, one still on its stump.
      Timer(const Duration(seconds: 9), () {
        final round = state.round!;
        for (var slot = 0; slot < round.activeSlots.length - 1; slot++) {
          state.dropOnSlot(slot, slot);
        }
      });
    }
  } else {
    final stage = scene.startsWith('a0')
        ? AgencyStage.observe
        : scene.startsWith('a1')
        ? AgencyStage.participate
        : AgencyStage.trigger;
    final state = HighLowGameState(agencyStage: stage);
    screen = HighLowScreen(gameState: state);
    // Act once the round is ready for it (the intro takes several seconds).
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      switch (scene) {
        case 'a0arrow':
          if (timer.tick < 18) return;
          state.tapInstrument(0);
          state.tapInstrument(1);
        case 'a2correct':
          if (timer.tick < 6) return;
          state.dropInstrument(state.currentPrompt!.targetSide);
        case 'a2wrong':
          if (timer.tick < 6) return;
          state.dropInstrument(1 - state.currentPrompt!.targetSide);
      }
      timer.cancel();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressState()..load()),
        ChangeNotifierProvider(create: (_) => SkillState()..load()),
        ChangeNotifierProvider(create: (_) => DevSettingsState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EarTrainerApp.buildTheme(),
        home: screen,
      ),
    ),
  );
}

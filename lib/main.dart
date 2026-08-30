import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'audio/audio_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (landscape only — see Trello "Change mobile
  // app to landscape" ticket).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize audio controller
  try {
    await AudioController.instance.init();
    // Preload audio assets in background
    AudioController.instance.preloadAll();
  } catch (e) {
    // Audio failed to initialize - app can still work without audio
    debugPrint('Audio initialization failed: $e');
  }

  runApp(const EarTrainerApp());
}

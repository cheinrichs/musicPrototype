import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'audio/audio_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait only for kids app)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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

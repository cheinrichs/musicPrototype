import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel driven from lib/audio/audio_session.dart.
  private static let audioSessionChannel = "ear_trainer/audio_session"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard
      let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionBridge")
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: AppDelegate.audioSessionChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "configureForPlayback" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.configurePlaybackSession())
    }
  }

  /// Put the shared audio session in the `playback` category.
  ///
  /// iOS defaults an app to `soloAmbient`, which the physical ring/silent
  /// switch silences. `playback` is the category Apple documents as staying
  /// audible with the switch set to silent — the right one for an app whose
  /// content *is* the audio.
  ///
  /// We deliberately do not pass `.mixWithOthers`: an ear-training prompt has
  /// to be heard on its own, so taking over the output from whatever else was
  /// playing is the behaviour we want. We also don't declare the `audio`
  /// background mode, so playback still stops when the app is backgrounded.
  private static func configurePlaybackSession() -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
      return true
    } catch {
      NSLog("[AudioSession] Could not set the playback category: \(error)")
      return false
    }
  }
}

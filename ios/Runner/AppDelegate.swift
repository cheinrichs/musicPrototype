import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel driven from lib/audio/audio_session.dart.
  private static let audioSessionChannel = "ear_trainer/audio_session"

  /// Channel driven from lib/app/build_distribution.dart.
  private static let buildInfoChannel = "ear_trainer/build_info"

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

    guard
      let buildInfoRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "BuildInfoBridge")
    else {
      return
    }

    let buildInfoChannel = FlutterMethodChannel(
      name: AppDelegate.buildInfoChannel,
      binaryMessenger: buildInfoRegistrar.messenger()
    )
    buildInfoChannel.setMethodCallHandler { call, result in
      guard call.method == "isInternalDistribution" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.isInternalDistribution())
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

  /// True unless this exact binary was installed from the public App
  /// Store — used to decide whether developer-only tools (the
  /// agency/tier/round-order gate, "Report this round") are safe to show.
  ///
  /// TestFlight and the App Store hand out the *same signed archive*, so
  /// nothing about the build itself (debug vs. release, a compile-time
  /// flag) can tell them apart — only where the install actually came
  /// from can. iOS records that by embedding a receipt at
  /// `Bundle.main.appStoreReceiptURL`, and the receipt's *filename*
  /// (verifying its contents needs a server round-trip we don't need
  /// here) already says which channel installed it: "receipt" for a
  /// genuine App Store install, "sandboxReceipt" for TestFlight. A local
  /// Xcode/debug run usually has no receipt file at all — treated as
  /// internal too, same as TestFlight.
  private static func isInternalDistribution() -> Bool {
    guard let receiptURL = Bundle.main.appStoreReceiptURL,
      FileManager.default.fileExists(atPath: receiptURL.path)
    else {
      return true
    }
    return receiptURL.lastPathComponent != "receipt"
  }
}

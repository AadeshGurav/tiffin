import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerScreenChannel(engineBridge)
  }

  /// `tiffin/screen` — keeps the display awake while the scanner is open.
  /// Disabling the idle timer is the only lever iOS gives an app here.
  private func registerScreenChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "TiffinScreen")?.messenger()
    else { return }

    FlutterMethodChannel(name: "tiffin/screen", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "setKeepAwake" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(true)
      }
  }
}

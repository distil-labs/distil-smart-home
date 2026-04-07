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

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ModelPath") else { return }
    let channel = FlutterMethodChannel(
      name: "com.distillabs.smarthome/model",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "getBundledModelPath" {
        let path = Bundle.main.bundlePath + "/smart-home-model"
        if FileManager.default.fileExists(atPath: path) {
          result(path)
        } else {
          result(nil as String?)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

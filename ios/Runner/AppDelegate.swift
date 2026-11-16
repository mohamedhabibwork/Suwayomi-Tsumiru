import Flutter
import LocalAuthentication
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

    let channel = FlutterMethodChannel(
      name: "app.firstcallmedical.manga/biometrics",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "authenticate":
        let args = call.arguments as? [String: Any]
        let reason = (args?["reason"] as? String)
          ?? "Authenticate with Face ID to sign in to Mangaka FC"
        let context = LAContext()
        var authError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
          context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
          ) { success, _ in
            DispatchQueue.main.async {
              result(success)
            }
          }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
          context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
          ) { success, _ in
            DispatchQueue.main.async {
              result(success)
            }
          }
        } else {
          // If neither Face ID nor device passcode is configured (e.g. simulator), allow fallback.
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

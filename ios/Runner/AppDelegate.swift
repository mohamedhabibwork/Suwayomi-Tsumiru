import Flutter
import LocalAuthentication
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenshotProtectionEnabled: Bool = true
  private var securityChannel: FlutterMethodChannel?
  private var blackoutOverlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    setupScreenCaptureNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func activeKeyWindow() -> UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for window in windowScene.windows where window.isKeyWindow {
          return window
        }
        if let first = windowScene.windows.first {
          return first
        }
      }
    }
    return self.window
  }

  private func setupScreenCaptureNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleUserDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
  }

  @objc private func handleScreenCaptureChanged() {
    let captured = UIScreen.main.isCaptured
    updateBlackoutOverlay(forceShow: captured && screenshotProtectionEnabled)
    securityChannel?.invokeMethod("onScreenCaptureChanged", arguments: ["captured": captured])
  }

  @objc private func handleDidEnterBackground() {
    if screenshotProtectionEnabled {
      updateBlackoutOverlay(forceShow: true)
    }
  }

  @objc private func handleWillEnterForeground() {
    let captured = UIScreen.main.isCaptured
    updateBlackoutOverlay(forceShow: captured && screenshotProtectionEnabled)
  }

  @objc private func handleDidBecomeActive() {
    let captured = UIScreen.main.isCaptured
    updateBlackoutOverlay(forceShow: captured && screenshotProtectionEnabled)
    securityChannel?.invokeMethod("onScreenCaptureChanged", arguments: ["captured": captured])
  }

  @objc private func handleUserDidTakeScreenshot() {
    if screenshotProtectionEnabled {
      securityChannel?.invokeMethod("onScreenshotTaken", arguments: nil)
    }
  }

  private func updateBlackoutOverlay(forceShow: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let window = self.activeKeyWindow() else { return }
      if forceShow {
        if self.blackoutOverlayView == nil {
          let overlay = UIView(frame: window.bounds)
          overlay.backgroundColor = .black
          overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
          overlay.isUserInteractionEnabled = false
          overlay.layer.zPosition = 999999
          window.addSubview(overlay)
          self.blackoutOverlayView = overlay
        }
        self.blackoutOverlayView?.frame = window.bounds
        self.blackoutOverlayView?.isHidden = false
        window.bringSubviewToFront(self.blackoutOverlayView!)
      } else {
        self.blackoutOverlayView?.isHidden = true
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let bioChannel = FlutterMethodChannel(
      name: "app.firstcallmedical.manga/biometrics",
      binaryMessenger: messenger
    )
    bioChannel.setMethodCallHandler { call, result in
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

    let secChannel = FlutterMethodChannel(
      name: "app.firstcallmedical.manga/security",
      binaryMessenger: messenger
    )
    self.securityChannel = secChannel
    secChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "setScreenshotProtection":
        let args = call.arguments as? [String: Any]
        let enabled = (args?["enabled"] as? Bool) ?? true
        self.screenshotProtectionEnabled = enabled
        self.updateBlackoutOverlay(forceShow: enabled && UIScreen.main.isCaptured)
        result(true)
      case "isScreenCaptured":
        result(UIScreen.main.isCaptured)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

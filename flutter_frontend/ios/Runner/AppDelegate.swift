import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "no.msgr.app/snap_camera_kit"
  private var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
  private var pendingResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      methodChannel.setMethodCallHandler(handle)
    }

    // Setup push method channel and register for notifications
    setupPushChannel()
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    supportedOrientations
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "openCameraKit":
      guard pendingResult == nil else {
        result(FlutterError(code: "in_use", message: "Camera Kit already presented", details: nil))
        return
      }

      guard let configuration = SnapCameraKitConfiguration(arguments: call.arguments) else {
        result(FlutterError(code: "invalid_config", message: "Missing Camera Kit configuration", details: nil))
        return
      }

      guard let controller = window?.rootViewController as? FlutterViewController else {
        result(FlutterError(code: "no_controller", message: "Missing Flutter controller", details: nil))
        return
      }

      pendingResult = result
      SnapCameraKitBridge.present(
        from: controller,
        configuration: configuration,
        result: { [weak self] payload in
          self?.pendingResult?(payload)
          self?.pendingResult = nil
        },
        cancellation: { [weak self] in
          self?.pendingResult?(nil)
          self?.pendingResult = nil
        }
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

  // MARK: - Push Notifications

  private var pushChannel: FlutterMethodChannel?

  private func setupPushChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    pushChannel = FlutterMethodChannel(name: "no.msgr.app/push", binaryMessenger: controller.binaryMessenger)
    pushChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestToken":
        // Token is sent via didRegisterForRemoteNotificationsWithDeviceToken
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    pushChannel?.invokeMethod("onPushToken", arguments: token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[Push] Failed to register: \(error)")
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Show notification even when app is in foreground
    completionHandler([.banner, .sound, .badge])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    pushChannel?.invokeMethod("onPushNotification", arguments: userInfo)
    completionHandler()
  }
}

extension AppDelegate: AppOrientationDelegate {
  func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
    supportedOrientations = orientation
  }

  func unlockOrientation() {
    supportedOrientations = .allButUpsideDown
  }
}

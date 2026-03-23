import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

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

  // MARK: - Push Notifications

  private var pushChannel: FlutterMethodChannel?
  private var cachedDeviceToken: String?

  private func setupPushChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    pushChannel = FlutterMethodChannel(name: "no.msgr.app/push", binaryMessenger: controller.binaryMessenger)
    pushChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestToken":
        // If we already have a token, send it immediately
        if let token = self?.cachedDeviceToken {
          self?.pushChannel?.invokeMethod("onPushToken", arguments: token)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[Push] Got device token: \(token.prefix(16))...")
    cachedDeviceToken = token
    pushChannel?.invokeMethod("onPushToken", arguments: token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[Push] Failed to register: \(error)")
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .badge])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    pushChannel?.invokeMethod("onPushNotification", arguments: userInfo)
    completionHandler()
  }
}

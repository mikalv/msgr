import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      print("[APNS] Permission granted: \(granted), error: \(String(describing: error))")
      if granted {
        DispatchQueue.main.async {
          NSApplication.shared.registerForRemoteNotifications()
        }
      }
    }
  }

  override func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[APNS] macOS token: \(token)")

    if let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let file = dir.appendingPathComponent("apns_token.txt")
      try? token.write(to: file, atomically: true, encoding: .utf8)
      print("[APNS] Written to \(file.path)")
    }
  }

  override func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[APNS] Failed: \(error)")
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .badge])
  }
}

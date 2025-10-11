import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "dev.meeh.messngr/snap_camera_kit"
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

extension AppDelegate: AppOrientationDelegate {
  func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
    supportedOrientations = orientation
  }

  func unlockOrientation() {
    supportedOrientations = .allButUpsideDown
  }
}

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Platform channel for dock badge and bounce
    let channel = FlutterMethodChannel(
      name: "no.msgr/dock",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "bounce":
        NSApp.requestUserAttention(.criticalRequest)
        result(nil)

      case "cancelBounce":
        NSApp.cancelUserAttentionRequest(0)
        result(nil)

      case "setBadge":
        if let args = call.arguments as? [String: Any],
           let count = args["count"] as? Int {
          NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

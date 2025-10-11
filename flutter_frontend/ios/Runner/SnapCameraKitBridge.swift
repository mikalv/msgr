import Flutter
import Foundation
import SCSDKCameraKit
import SCSDKCameraKitReferenceUI
import UIKit

struct SnapCameraKitConfiguration {
    let applicationId: String
    let apiToken: String
    let lensGroupIds: [String]

    init?(arguments: Any?) {
        guard let payload = arguments as? [String: Any] else { return nil }
        guard let apiToken = payload["apiToken"] as? String, !apiToken.isEmpty else { return nil }
        guard let applicationId = payload["applicationId"] as? String else { return nil }
        guard let lensGroupIds = payload["lensGroupIds"] as? [String], !lensGroupIds.isEmpty else { return nil }

        self.apiToken = apiToken
        self.applicationId = applicationId
        self.lensGroupIds = lensGroupIds
    }
}

enum SnapCameraKitBridge {
    static func present(
        from controller: FlutterViewController,
        configuration: SnapCameraKitConfiguration,
        result: @escaping FlutterResult,
        cancellation: @escaping () -> Void
    ) {
        let cameraController = CameraController(
            sessionConfig: SessionConfig(applicationID: configuration.applicationId, apiToken: configuration.apiToken)
        )
        cameraController.groupIDs = configuration.lensGroupIds

        let cameraViewController = FlutterCameraViewController(cameraController: cameraController)
        cameraViewController.modalPresentationStyle = .fullScreen

        cameraViewController.onDismiss = {
            guard let path = cameraViewController.url?.path,
                  let mimeType = cameraViewController.mimeType else {
                cancellation()
                return
            }
            result(["path": path, "mime_type": mimeType])
        }

        cameraViewController.appOrientationDelegate = controller.appDelegate

        controller.present(cameraViewController, animated: false)
    }
}

private extension FlutterViewController {
    var appDelegate: AppOrientationDelegate? {
        UIApplication.shared.delegate as? AppOrientationDelegate
    }
}

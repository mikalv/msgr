package dev.meeh.messngr

import android.widget.Toast
import androidx.core.net.toFile
import com.snap.camerakit.support.app.CameraActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val channelName = "dev.meeh.messngr/snap_camera_kit"
    private lateinit var methodChannel: MethodChannel
    private var pendingResult: MethodChannel.Result? = null

    private val captureLauncher = registerForActivityResult(CameraActivity.Capture) { captureResult ->
        val result = pendingResult ?: return@registerForActivityResult
        pendingResult = null
        when (captureResult) {
            is CameraActivity.Capture.Result.Success.Video -> {
                val path = captureResult.uri.toFile().absolutePath
                result.success(mapOf("path" to path, "mime_type" to "video/mp4"))
            }
            is CameraActivity.Capture.Result.Success.Image -> {
                val path = captureResult.uri.toFile().absolutePath
                result.success(mapOf("path" to path, "mime_type" to "image/jpeg"))
            }
            is CameraActivity.Capture.Result.Cancelled -> {
                result.success(null)
            }
            is CameraActivity.Capture.Result.Failure -> {
                Toast.makeText(this, "Camera Kit failed", Toast.LENGTH_SHORT).show()
                result.error("failure", "Camera Kit capture failed", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "openCameraKit" -> openCameraKit(call, result)
            else -> result.notImplemented()
        }
    }

    private fun openCameraKit(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("in_use", "Camera Kit is already running", null)
            return
        }

        val apiToken = call.argument<String>("apiToken")
        val lensGroupIds = call.argument<List<String>>("lensGroupIds")

        if (apiToken.isNullOrEmpty() || lensGroupIds.isNullOrEmpty()) {
            result.error("invalid_config", "Camera Kit configuration missing", null)
            return
        }

        pendingResult = result
        captureLauncher.launch(
            CameraActivity.Configuration.WithLenses(
                cameraKitApiToken = apiToken,
                lensGroupIds = lensGroupIds.toTypedArray()
            )
        )
    }
}

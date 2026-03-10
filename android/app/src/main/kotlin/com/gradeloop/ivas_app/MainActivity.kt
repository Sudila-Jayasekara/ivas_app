package com.gradeloop.ivas_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gradeloop.ivas/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "isSimulator") {
                    val isEmulator = (Build.FINGERPRINT.startsWith("generic")
                            || Build.FINGERPRINT.startsWith("unknown")
                            || Build.MODEL.contains("google_sdk")
                            || Build.MODEL.contains("Emulator")
                            || Build.MODEL.contains("Android SDK built for x86")
                            || Build.MANUFACTURER.contains("Genymotion")
                            || Build.BRAND.startsWith("generic")
                            || Build.DEVICE.startsWith("generic")
                            || "google_sdk" == Build.PRODUCT)
                    result.success(isEmulator)
                } else {
                    result.notImplemented()
                }
            }
    }
}

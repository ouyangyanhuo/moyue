package com.moyue.application

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.moyue.application/storage"
        ).setMethodCallHandler { call, result ->
            if (call.method == "externalFilesDir") {
                result.success(getExternalFilesDir(null)?.absolutePath)
            } else {
                result.notImplemented()
            }
        }
    }
}

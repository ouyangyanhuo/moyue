package com.moyue.application

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    private fun requestHighRefreshRate() {
        val maximum = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            display?.supportedModes?.maxOfOrNull { it.refreshRate } ?: 120f
        } else {
            @Suppress("DEPRECATION")
            (windowManager.defaultDisplay?.refreshRate ?: 60f)
        }
        val attributes = window.attributes
        attributes.preferredRefreshRate = maximum
        window.attributes = attributes
        if (Build.VERSION.SDK_INT >= 35) {
            window.decorView.requestedFrameRate = View.REQUESTED_FRAME_RATE_CATEGORY_HIGH
        }
    }

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.moyue.application/system"
        ).setMethodCallHandler { call, result ->
            if (call.method == "restartApp") {
                result.success(true)
                Handler(Looper.getMainLooper()).post {
                    // recreate() 在部分定制 Android 系统上会把 FlutterActivity
                    // 从任务栈移除而不重新创建，用户会直接回到桌面。重新建立应用
                    // 的根任务可稳定启动新的 FlutterEngine，同时不结束应用进程。
                    val restartIntent = Intent.makeRestartActivityTask(componentName)
                    startActivity(restartIntent)
                    @Suppress("DEPRECATION")
                    overridePendingTransition(0, 0)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

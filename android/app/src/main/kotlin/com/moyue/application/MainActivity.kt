package com.moyue.application

import android.app.WallpaperManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var incomingFilesChannel: MethodChannel? = null
    private val pendingIncomingFiles = mutableListOf<Map<String, String>>()
    private val incomingFilesExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
        captureIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIncomingIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    override fun onDestroy() {
        incomingFilesChannel?.setMethodCallHandler(null)
        incomingFilesExecutor.shutdownNow()
        super.onDestroy()
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
        incomingFilesChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.moyue.application/incoming_files"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "takePendingFiles") {
                    val files = pendingIncomingFiles.toList()
                    pendingIncomingFiles.clear()
                    result.success(files)
                } else {
                    result.notImplemented()
                }
            }
        }
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
            when (call.method) {
                "restartApp" -> {
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
                }
                "systemAppearance" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                    val seed = if (supported) resolveDynamicSeedColor() else null
                    result.success(
                        mapOf(
                            "dynamicColorSupported" to supported,
                            "seedArgb" to seed
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Android does not expose Monet's chosen seed directly. WallpaperColors'
     * primary color is the public wallpaper-derived source closest to that
     * seed, and unlike system_accent1_500 it is not held by an OEM theme
     * resource cache after a wallpaper change. The system accent remains a
     * safe fallback for live wallpapers or launchers that publish no colors.
     */
    private fun resolveDynamicSeedColor(): Long? {
        val wallpaperSeed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                WallpaperManager.getInstance(this)
                    .getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
                    ?.primaryColor
                    ?.toArgb()
            } catch (_: Exception) {
                null
            }
        } else {
            null
        }
        val color = wallpaperSeed ?: try {
            getColor(android.R.color.system_accent1_500)
        } catch (_: Exception) {
            return null
        }
        return color.toLong() and 0xFFFFFFFFL
    }

    private fun captureIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val supportedAction = intent.action == Intent.ACTION_VIEW ||
            intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE
        if (!supportedAction) return

        val uris = mutableListOf<Uri>()
        intent.data?.let(uris::add)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)?.let(uris::add)
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                ?.let(uris::addAll)
        } else {
            @Suppress("DEPRECATION")
            (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let(uris::add)
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::addAll)
        }
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let(uris::add)
            }
        }
        val uniqueUris = uris.distinctBy(Uri::toString)
        if (uniqueUris.isEmpty()) return
        val fallbackMimeType = intent.type
        incomingFilesExecutor.execute {
            val staged = uniqueUris.mapNotNull { uri ->
                stageIncomingUri(uri, fallbackMimeType)
            }
            if (staged.isEmpty()) return@execute
            runOnUiThread {
                pendingIncomingFiles.addAll(staged)
                incomingFilesChannel?.invokeMethod("incomingFilesAvailable", null)
            }
        }
    }

    private fun stageIncomingUri(uri: Uri, fallbackMimeType: String?): Map<String, String>? {
        val displayName = queryDisplayName(uri)
            ?: uri.lastPathSegment?.substringAfterLast('/')
            ?: "imported-file"
        var safeName = displayName
            .replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
            .take(160)
            .ifBlank { "imported-file" }
        var extension = safeName.substringAfterLast('.', "").lowercase()
        if (extension !in SUPPORTED_EXTENSIONS) {
            val mimeExtension = extensionForMimeType(
                contentResolver.getType(uri) ?: fallbackMimeType
            ) ?: return null
            safeName = if (safeName.contains('.')) {
                "${safeName.substringBeforeLast('.')}.$mimeExtension"
            } else {
                "$safeName.$mimeExtension"
            }
            extension = mimeExtension
        }
        if (extension !in SUPPORTED_EXTENSIONS) return null

        val incomingDirectory = File(cacheDir, "incoming-files").apply { mkdirs() }
        val target = File(incomingDirectory, "${UUID.randomUUID()}-$safeName")
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use(input::copyTo)
            } ?: return null
            mapOf("name" to safeName, "path" to target.absolutePath)
        } catch (_: Exception) {
            target.delete()
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? = try {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
    } catch (_: Exception) {
        null
    }

    private fun extensionForMimeType(mimeType: String?): String? = when (
        mimeType?.substringBefore(';')?.trim()?.lowercase()
    ) {
        "text/markdown", "text/x-markdown" -> "md"
        "text/html", "application/xhtml+xml" -> "html"
        "application/zip", "application/x-zip-compressed" -> "zip"
        "application/x-moyue" -> "moyue"
        else -> null
    }

    companion object {
        private val SUPPORTED_EXTENSIONS = setOf("md", "html", "zip", "moyue")
    }
}

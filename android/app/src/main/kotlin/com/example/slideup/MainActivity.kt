package com.slideup.mediaplayer

import android.app.PictureInPictureParams
import android.app.WallpaperManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import cl.puntito.simple_pip_mode.PipCallbackHelper
import java.io.File

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val TAG = "MainActivity"

        private const val WALLPAPER_CHANNEL = "com.slideup.mediaplayer/wallpaper"
        private const val INTENT_METHOD_CHANNEL = "com.slideup.mediaplayer/intent"
        private const val INTENT_STREAM_CHANNEL = "com.slideup.mediaplayer/intent_stream"
        private const val BACKGROUND_VIDEO_CHANNEL = "com.slideup.mediaplayer/background_video"
    }

    private var intentSink: EventChannel.EventSink? = null
    private var initialIntentPath: String? = null
    private var pendingIntentPath: String? = null
    private var callbackHelper = PipCallbackHelper()

    // Whether PiP auto-enter is currently enabled (set by Flutter when a video is playing)
    private var pipAutoEnterEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // IMPORTANT: Explicitly register all plugins, including Workmanager
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // If you want, you can still call super afterwards,
        // but the key part is the GeneratedPluginRegistrant line above.
        super.configureFlutterEngine(flutterEngine)

        setupBackgroundVideoChannel(flutterEngine)
        setupIntentMethodChannel(flutterEngine)
        setupIntentEventChannel(flutterEngine)
        setupWallpaperChannel(flutterEngine)
        callbackHelper.configureFlutterEngine(flutterEngine)

        // Process launch intent
        processLaunchIntent()
    }

    private fun processLaunchIntent() {
        val uri = extractUriFromIntent(intent)
        if (uri != null) {
            val path = getFilePathFromUri(uri)
            if (path != null) {
                Log.d(TAG, "🚀 Cold start with file: $path")
                initialIntentPath = path
            }
        }
    }

    /* ---------------- Background Video Channel ---------------- */
    private fun setupBackgroundVideoChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_VIDEO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBackgroundPlayback" -> {
                    try {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Background playback error", e)
                        result.error("BACKGROUND_ERROR", e.message, null)
                    }
                }
                "disableBackgroundPlayback" -> {
                    try {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BACKGROUND_ERROR", e.message, null)
                    }
                }
                "enterPiPMode" -> {
                    enterPiPMode(result)
                }
                "isPiPSupported" -> {
                    result.success(isPiPSupported())
                }
                // Called by Flutter when playback starts/stops so we know
                // whether to auto-enter PiP when the user presses Home.
                "setPiPAutoEnter" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    pipAutoEnterEnabled = enabled
                    // On Android 12+ we can tell the system up-front so it
                    // can animate the transition without a separate call.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setPictureInPictureParams(
                            buildPipParams(autoEnter = enabled)
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /* ---------------- Intent Method Channel ---------------- */
    private fun setupIntentMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTENT_METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> {
                    Log.d(TAG, "📱 Flutter requesting initial intent: $initialIntentPath")
                    result.success(initialIntentPath)
                }
                "getPendingIntent" -> {
                    Log.d(TAG, "📱 Flutter requesting pending intent: $pendingIntentPath")
                    val path = pendingIntentPath
                    pendingIntentPath = null
                    result.success(path)
                }
                "hasPendingIntent" -> {
                    result.success(pendingIntentPath != null)
                }
                "clearIntent" -> {
                    Log.d(TAG, "🧹 Clearing all intents")
                    initialIntentPath = null
                    pendingIntentPath = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /* ---------------- Intent Event Channel ---------------- */
    private fun setupIntentEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTENT_STREAM_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "📡 Flutter stream CONNECTED")
                intentSink = events

                pendingIntentPath?.let { path ->
                    Log.d(TAG, "📤 Sending pending intent to stream: $path")
                    runOnUiThread {
                        intentSink?.success(path)
                    }
                    pendingIntentPath = null
                }
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "📡 Flutter stream DISCONNECTED")
                intentSink = null
            }
        })
    }

    /* ---------------- Wallpaper Channel ---------------- */
    private fun setupWallpaperChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WALLPAPER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setWallpaper" -> {
                    val path = call.argument<String>("path")
                    val wallpaperType = call.argument<Int>("type") ?: WallpaperManager.FLAG_SYSTEM

                    if (path == null) {
                        result.error("INVALID_PATH", "Image path is null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "Image file does not exist", null)
                            return@setMethodCallHandler
                        }

                        val bitmap = BitmapFactory.decodeFile(path)
                        if (bitmap == null) {
                            result.error("DECODE_ERROR", "Failed to decode image", null)
                            return@setMethodCallHandler
                        }

                        val wallpaperManager = WallpaperManager.getInstance(applicationContext)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            wallpaperManager.setBitmap(bitmap, null, true, wallpaperType)
                        } else {
                            wallpaperManager.setBitmap(bitmap)
                        }

                        bitmap.recycle()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Wallpaper error", e)
                        result.error("WALLPAPER_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /* ---------------- Lifecycle Methods ---------------- */

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "✅ Activity created")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        Log.d(TAG, "🔄 onNewIntent - Action: ${intent.action}")

        val uri = extractUriFromIntent(intent)
        if (uri == null) {
            Log.d(TAG, "⚠️ No URI in intent")
            return
        }

        val path = getFilePathFromUri(uri)
        if (path == null) {
            Log.e(TAG, "❌ Failed to resolve path from URI: $uri")
            return
        }

        Log.d(TAG, "📂 New intent file: $path")
        Log.d(TAG, "📡 intentSink status: ${if (intentSink != null) "CONNECTED" else "NULL"}")

        if (intentSink != null) {
            Log.d(TAG, "📤 Sending directly to Flutter stream")
            runOnUiThread {
                intentSink?.success(path)
            }
        } else {
            Log.d(TAG, "📦 Storing as pending intent (stream not connected)")
            pendingIntentPath = path
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "🔄 Activity resumed - pendingIntent: $pendingIntentPath, sinkConnected: ${intentSink != null}")

        if (pendingIntentPath != null && intentSink != null) {
            Log.d(TAG, "📤 Sending pending intent on resume: $pendingIntentPath")
            runOnUiThread {
                intentSink?.success(pendingIntentPath)
                pendingIntentPath = null
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        intentSink = null
        cleanupTempFiles()
        Log.d(TAG, "❌ Activity destroyed")
    }

    /* ---------------- Extract URI from Intent ---------------- */

    private fun extractUriFromIntent(intent: Intent?): Uri? {
        if (intent == null) return null

        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> getUriFromSendIntent(intent)
            Intent.ACTION_SEND_MULTIPLE -> getFirstUriFromSendMultipleIntent(intent)
            else -> null
        }
    }

    @Suppress("DEPRECATION")
    private fun getUriFromSendIntent(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        } ?: intent.data
    }

    @Suppress("DEPRECATION")
    private fun getFirstUriFromSendMultipleIntent(intent: Intent): Uri? {
        val uriList: ArrayList<Uri>? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("UNCHECKED_CAST")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
        return uriList?.firstOrNull()
    }

    /* ---------------- Picture-in-Picture ---------------- */

    /** Returns true if the device supports PiP (Android 8+). */
    private fun isPiPSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    /**
     * Builds a [PictureInPictureParams] with a 16:9 aspect ratio.
     * On Android 12+ also sets [autoEnter] so the system can smoothly
     * transition without a separate [enterPictureInPictureMode] call.
     */
    private fun buildPipParams(autoEnter: Boolean = false): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }
        return builder.build()
    }

    /**
     * Explicitly enter PiP (called from Flutter via MethodChannel).
     * Works on Android 8+ (API 26+).
     */
    private fun enterPiPMode(result: MethodChannel.Result) {
        if (!isPiPSupported()) {
            result.error("PIP_NOT_SUPPORTED", "PiP requires Android 8.0+ with PiP feature", null)
            return
        }
        try {
            val success = enterPictureInPictureMode(buildPipParams(autoEnter = false))
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "PiP error", e)
            result.error("PIP_ERROR", e.message, null)
        }
    }

    /**
     * AUTO-ENTER PiP when the user presses Home or switches apps.
     * This is the KEY method that was missing — without it PiP only works
     * when triggered explicitly (e.g. a button tap inside the app).
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipAutoEnterEnabled && isPiPSupported()) {
            Log.d(TAG, "🏠 Home pressed — auto-entering PiP")
            try {
                enterPictureInPictureMode(buildPipParams(autoEnter = false))
            } catch (e: Exception) {
                Log.e(TAG, "Auto-PiP on home failed", e)
            }
        }
    }

    /** Called by Android when PiP mode changes. Notifies the Flutter layer. */
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        callbackHelper.onPictureInPictureModeChanged(isInPictureInPictureMode)
        Log.d(TAG, if (isInPictureInPictureMode) "✅ Entered PiP" else "❌ Exited PiP")
    }

    /* ---------------- URI → File Path ---------------- */

    private fun getFilePathFromUri(uri: Uri): String? {
        return try {
            when (uri.scheme) {
                "file" -> uri.path
                "content" -> getPathFromContentUri(uri)
                else -> {
                    Log.w(TAG, "Unknown URI scheme: ${uri.scheme}")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting path from URI", e)
            null
        }
    }

    private fun getPathFromContentUri(uri: Uri): String? {
        val realPath = getRealPathFromMediaStore(uri)
        if (realPath != null && File(realPath).exists()) {
            Log.d(TAG, "📍 Resolved via MediaStore: $realPath")
            return realPath
        }

        val cachedPath = copyUriToCache(uri)
        if (cachedPath != null) {
            Log.d(TAG, "📍 Copied to cache: $cachedPath")
        }
        return cachedPath
    }

    private fun getRealPathFromMediaStore(uri: Uri): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DATA)

        return try {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex =
                        cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                    cursor.getString(columnIndex)
                } else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "MediaStore query failed: ${e.message}")
            return null
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val fileName =
                getFileName(uri) ?: "shared_${System.currentTimeMillis()}"
            val cacheDir = File(cacheDir, "shared_intents")

            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            val destFile = File(cacheDir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            destFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to copy URI to cache", e)
            null
        }
    }

    private fun getFileName(uri: Uri): String? {
        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex =
                        cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        return cursor.getString(nameIndex)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get file name", e)
        }
        return uri.lastPathSegment
    }

    /* ---------------- Cleanup ---------------- */

    private fun cleanupTempFiles() {
        try {
            val cacheDir = File(cacheDir, "shared_intents")
            if (cacheDir.exists()) {
                cacheDir.listFiles()?.forEach { file ->
                    if (System.currentTimeMillis() - file.lastModified() > 3600000) {
                        file.delete()
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Cleanup failed", e)
        }
    }
}
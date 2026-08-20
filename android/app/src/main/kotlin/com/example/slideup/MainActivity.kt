package com.slideup.mediaplayer

import android.app.Activity
import android.app.PictureInPictureParams
import android.app.PendingIntent
import android.app.RemoteAction
import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
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
        private const val SAF_CHANNEL = "com.slideup.mediaplayer/saf"
        private const val SAF_TREE_REQUEST = 4001

        private const val PIP_ACTION_BROADCAST = "com.slideup.mediaplayer.PIP_ACTION"
        private const val PIP_ACTION_PLAY_PAUSE = "play_pause"
        private const val PIP_ACTION_PREVIOUS = "previous"
        private const val PIP_ACTION_NEXT = "next"
    }

    private var intentSink: EventChannel.EventSink? = null
    private var initialIntentPath: String? = null
    private var pendingIntentPath: String? = null
    private var callbackHelper = PipCallbackHelper()

    // Channel used to push native PiP action taps down to Flutter.
    private var backgroundChannel: MethodChannel? = null

    // SAF (Storage Access Framework): lets us delete files on removable
    // volumes (USB OTG / SD card) that block raw file-path writes on old
    // Android versions. Tree URIs are persisted per volume in SharedPreferences.
    private var safPendingResult: MethodChannel.Result? = null
    private val safPrefs: SharedPreferences by lazy {
        getSharedPreferences("saf_trees", Context.MODE_PRIVATE)
    }

    /**
     * Receives PiP menu button taps (PendingIntent broadcasts registered in
     * [buildPipActions]) and forwards them to Flutter so playback can be
     * controlled from the OS PiP window while the app is backgrounded.
     */
    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.getStringExtra("action") ?: return
            Log.d(TAG, "🖱️ PiP action received: $action")
            backgroundChannel?.invokeMethod(
                "pipAction", action,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {}
                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?
                    ) {
                        Log.e(TAG, "pipAction channel error: $errorCode $errorMessage")
                    }

                    override fun notImplemented() {}
                }
            )
        }
    }

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
        setupSafChannel(flutterEngine)
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
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_VIDEO_CHANNEL
        )
        backgroundChannel = channel
        channel.setMethodCallHandler { call, result ->
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

    /* ---------------- SAF Channel ---------------- */

    private fun setupSafChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Deletes a file on a removable volume via SAF.
                // Returns "ok" | "error" | "needs_tree".
                "deleteFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                        return@setMethodCallHandler
                    }
                    val rootId = removableRootIdForPath(filePath)
                    if (rootId == null) {
                        result.error("NOT_REMOVABLE", "Not a removable volume path: $filePath", null)
                        return@setMethodCallHandler
                    }
                    val treeUriStr = safPrefs.getString("tree_$rootId", null)
                    if (treeUriStr == null) {
                        result.success("needs_tree")
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri = Uri.parse(treeUriStr)
                        val docUri = DocumentsContract.buildDocumentUri(
                            treeUri.authority,
                            documentIdForPath(filePath, rootId)
                        )
                        val deleted = DocumentsContract.deleteDocument(contentResolver, docUri)
                        Log.d(TAG, "🗑️ SAF delete $filePath -> $deleted")
                        result.success(if (deleted) "ok" else "error")
                    } catch (e: Exception) {
                        Log.e(TAG, "SAF delete failed for $filePath", e)
                        result.error("SAF_ERROR", e.message, null)
                    }
                }
                // Launches the system folder picker so the user can grant
                // access to a removable volume. Returns the persisted tree
                // URI, or null if cancelled.
                "pickTree" -> {
                    if (safPendingResult != null) {
                        result.error("PICK_IN_PROGRESS", "A picker is already open", null)
                        return@setMethodCallHandler
                    }
                    safPendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    )
                    try {
                        startActivityForResult(intent, SAF_TREE_REQUEST)
                    } catch (e: Exception) {
                        safPendingResult = null
                        Log.e(TAG, "Failed to open SAF tree picker", e)
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                // Stores a tree URI granted through any picker (e.g. the
                // `saf` plugin's pickDirectory) into the persisted registry
                // so deleteFile can reuse it. Returns the volume root id, or
                // null when the URI is not a removable-volume tree.
                "storeTree" -> {
                    val treeUriStr = call.argument<String>("treeUri")
                    if (treeUriStr == null) {
                        result.error("INVALID_URI", "Tree URI is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri = Uri.parse(treeUriStr)
                        val rootId = rootIdFromTreeUri(treeUri)
                        if (rootId == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        safPrefs.edit().putString("tree_$rootId", treeUriStr).apply()
                        Log.d(TAG, "🔑 SAF tree stored for volume $rootId")
                        result.success(rootId)
                    } catch (e: Exception) {
                        Log.e(TAG, "SAF storeTree failed", e)
                        result.error("STORE_ERROR", e.message, null)
                    }
                }
                // Writes bytes to a file through SAF (removable) or direct I/O (emulated).
                // Returns "ok" | "needs_tree" | "error".
                "writeFile" -> {
                    val filePath = call.argument<String>("path")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (filePath == null || bytes == null) {
                        result.error("INVALID_ARGS", "Path or bytes is null", null)
                        return@setMethodCallHandler
                    }
                    val rootId = removableRootIdForPath(filePath)
                    if (rootId != null) {
                        // Removable volume — must use SAF
                        val treeUriStr = safPrefs.getString("tree_$rootId", null)
                        if (treeUriStr == null) {
                            result.success("needs_tree")
                            return@setMethodCallHandler
                        }
                        try {
                            val treeUri = Uri.parse(treeUriStr)
                            val docUri = DocumentsContract.buildDocumentUri(
                                treeUri.authority,
                                documentIdForPath(filePath, rootId)
                            )
                            contentResolver.openOutputStream(docUri, "w")?.use { stream ->
                                stream.write(bytes)
                            }
                            Log.d(TAG, "📝 SAF write $filePath (${bytes.size} bytes)")
                            result.success("ok")
                        } catch (e: Exception) {
                            Log.e(TAG, "SAF write failed for $filePath", e)
                            result.error("SAF_ERROR", e.message, null)
                        }
                    } else {
                        // Emulated / internal — direct File I/O
                        try {
                            val file = File(filePath)
                            file.parentFile?.mkdirs()
                            file.writeBytes(bytes)
                            Log.d(TAG, "📝 Direct write $filePath (${bytes.size} bytes)")
                            result.success("ok")
                        } catch (e: Exception) {
                            Log.e(TAG, "Direct write failed for $filePath", e)
                            result.error("WRITE_ERROR", e.message, null)
                        }
                    }
                }
                // Opens the system "All files access" settings page directly.
                // Returns "granted" | "denied".
                "openManageStorageSettings" -> {
                    try {
                        val intent = Intent(
                            android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success("ok")
                    } catch (e: Exception) {
                        // Fallback: open generic storage settings
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success("ok")
                        } catch (e2: Exception) {
                            Log.e(TAG, "Failed to open storage settings", e2)
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Returns the volume id (e.g. "01A6-5A72") for a removable-storage path, or null. */
    private fun removableRootIdForPath(filePath: String): String? {
        if (!filePath.startsWith("/storage/")) return null
        val rest = filePath.removePrefix("/storage/")
        val slash = rest.indexOf('/')
        val segment = if (slash == -1) rest else rest.substring(0, slash)
        if (segment.isEmpty() || segment.equals("emulated", ignoreCase = true)) return null
        return segment
    }

    /** Builds a SAF documentId ("ROOT:relative/path") for a file under a volume root. */
    private fun documentIdForPath(filePath: String, rootId: String): String {
        val prefix = "/storage/$rootId/"
        val relative = if (filePath.startsWith(prefix)) {
            filePath.removePrefix(prefix)
        } else {
            filePath.removePrefix("/storage/$rootId")
        }
        return "$rootId:$relative"
    }

    /** Extracts the volume id from a picked tree URI (…/tree/01A6-5A72%3A). */
    private fun rootIdFromTreeUri(treeUri: Uri): String? {
        val last = treeUri.lastPathSegment ?: return null
        val decoded = Uri.decode(last)
        return decoded.removeSuffix(":").takeIf { it.isNotEmpty() }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAF_TREE_REQUEST) return
        val pending = safPendingResult
        safPendingResult = null
        if (resultCode == Activity.RESULT_OK && data?.data != null) {
            val treeUri = data.data!!
            try {
                contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                val rootId = rootIdFromTreeUri(treeUri)
                if (rootId != null) {
                    safPrefs.edit().putString("tree_$rootId", treeUri.toString()).apply()
                    Log.d(TAG, "🔑 SAF access granted for volume $rootId")
                }
                pending?.success(treeUri.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist SAF tree permission", e)
                pending?.error("PERSIST_ERROR", e.message, null)
            }
        } else {
            pending?.success(null)
        }
    }

    /* ---------------- Lifecycle Methods ---------------- */

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "✅ Activity created")
        val filter = IntentFilter(PIP_ACTION_BROADCAST)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(pipActionReceiver, filter)
        }
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
        try {
            unregisterReceiver(pipActionReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "pipActionReceiver already unregistered")
        }
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
     * Builds a [PictureInPictureParams] with a 16:9 aspect ratio and the
     * media-control actions (previous / play-pause / next).
     * On Android 12+ also sets [autoEnter] so the system can smoothly
     * transition without a separate [enterPictureInPictureMode] call.
     */
    private fun buildPipParams(autoEnter: Boolean = false): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            buildPipActions()?.let { builder.setActions(it) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }
        return builder.build()
    }

    /**
     * Registers play/pause + prev/next as PiP menu actions (Android O+).
     * Tapping them broadcasts [PIP_ACTION_BROADCAST] which [pipActionReceiver]
     * forwards to Flutter over the background-video channel.
     */
    private fun buildPipActions(): List<RemoteAction>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null

        fun pipAction(
            iconId: Int,
            requestCode: Int,
            title: String,
            action: String
        ): RemoteAction {
            val intent = Intent(PIP_ACTION_BROADCAST)
                .setPackage(packageName)
                .putExtra("action", action)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            return RemoteAction(
                Icon.createWithResource(this, iconId),
                title,
                title,
                pendingIntent
            )
        }

        return listOf(
            pipAction(android.R.drawable.ic_media_previous, 1001, "Previous", PIP_ACTION_PREVIOUS),
            pipAction(android.R.drawable.ic_media_play, 1002, "Play / Pause", PIP_ACTION_PLAY_PAUSE),
            pipAction(android.R.drawable.ic_media_next, 1003, "Next", PIP_ACTION_NEXT)
        )
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
                val entered = enterPictureInPictureMode(buildPipParams(autoEnter = false))
                if (!entered) {
                    Log.w(TAG, "⚠️ enterPictureInPictureMode returned false")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Auto-PiP on home failed", e)
            }
        }
    }

    /**
     * Fallback for OEMs (e.g. Oppo/ColorOS) that never fire onUserLeaveHint.
     * If playback auto-PiP is enabled and we genuinely left the foreground
     * (window lost focus), enter PiP shortly after pausing.
     */
    override fun onPause() {
        super.onPause()
        if (pipAutoEnterEnabled && isPiPSupported() &&
            !isInPictureInPictureMode() && !isFinishing && !isChangingConfigurations
        ) {
            window.decorView.postDelayed({
                if (pipAutoEnterEnabled && !isInPictureInPictureMode() &&
                    !isFinishing && !isChangingConfigurations && !window.decorView.hasFocus()
                ) {
                    Log.d(TAG, "📺 onPause fallback — entering PiP")
                    try {
                        enterPictureInPictureMode(buildPipParams(autoEnter = false))
                    } catch (e: Exception) {
                        Log.e(TAG, "Auto-PiP on pause failed", e)
                    }
                }
            }, 200)
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
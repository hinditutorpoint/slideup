import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/safe_async.dart';

/// Notification action identifiers
class NotificationActions {
  static const String pause = 'pause_download';
  static const String resume = 'resume_download';
  static const String cancel = 'cancel_download';
  static const String retry = 'retry_download';
  static const String open = 'open_book';
  static const String dismiss = 'dismiss';
}

/// Notification payload
class NotificationPayload {
  final String type;
  final String? taskId;
  final String? bookId;
  final String? action;
  final Map<String, dynamic>? extra;

  const NotificationPayload({
    required this.type,
    this.taskId,
    this.bookId,
    this.action,
    this.extra,
  });

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      type: json['type'] as String? ?? '',
      taskId: json['taskId'] as String?,
      bookId: json['bookId'] as String?,
      action: json['action'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'taskId': taskId,
    'bookId': bookId,
    'action': action,
    'extra': extra,
  };

  String encode() {
    return '$type|${taskId ?? ''}|${bookId ?? ''}|${action ?? ''}';
  }

  factory NotificationPayload.decode(String encoded) {
    final parts = encoded.split('|');
    return NotificationPayload(
      type: parts.isNotEmpty ? parts[0] : '',
      taskId: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      bookId: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      action: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }
}

/// Notification callback handler
typedef NotificationCallback = void Function(NotificationPayload payload);

/// Notification Service for download progress and status
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification callbacks
  final List<NotificationCallback> _actionCallbacks = [];

  // Active notification IDs
  final Map<String, int> _activeNotifications = {};

  // Notification ID counter
  int _notificationIdCounter = AppConstants.downloadNotificationId;

  // Is initialized
  bool _isInitialized = false;

  // Stream controller for notification actions
  final StreamController<NotificationPayload> _actionController =
      StreamController<NotificationPayload>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  Stream<NotificationPayload> get actionStream => _actionController.stream;

  /// Initialize notification service
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS initialization settings
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // macOS initialization settings
      final macOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Linux initialization settings
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
        defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
      );

      // Combined initialization settings
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macOSSettings,
        linux: linuxSettings,
      );

      // Initialize plugin
      final initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );

      if (initialized != true) {
        debugPrint('Warning: Notifications may not be fully initialized');
      }

      // Request permissions on Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }

      // Create notification channels for Android
      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('NotificationService initialized');
    }, operationName: 'NotificationService.initialize');
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      await cancelAllNotifications();
      await _actionController.close();
      _actionCallbacks.clear();
      _activeNotifications.clear();
      _isInitialized = false;
      debugPrint('NotificationService disposed');
    } catch (e) {
      debugPrint('NotificationService dispose error: $e');
    }
  }

  /// Request Android notification permissions
  Future<void> _requestAndroidPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Failed to request Android permissions: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        // Download progress channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.downloadChannelId,
            AppConstants.downloadChannelName,
            description: AppConstants.downloadChannelDesc,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );

        // Download complete channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'epub_download_complete',
            'Download Complete',
            description: 'Notifications when downloads complete',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // Download error channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'epub_download_error',
            'Download Errors',
            description: 'Notifications for download errors',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to create notification channels: $e');
    }
  }

  // ===========================================================================
  // DOWNLOAD NOTIFICATIONS
  // ===========================================================================

  /// Show download started notification
  Future<Result<int>> showDownloadStarted({
    required String taskId,
    required String bookTitle,
    String? bookId,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = _getOrCreateNotificationId(taskId);

      final androidDetails = AndroidNotificationDetails(
        AppConstants.downloadChannelId,
        AppConstants.downloadChannelName,
        channelDescription: AppConstants.downloadChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        maxProgress: 100,
        progress: 0,
        actions: [
          const AndroidNotificationAction(
            NotificationActions.cancel,
            'Cancel',
            showsUserInterface: false,
            cancelNotification: false,
          ),
        ],
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = NotificationPayload(
        type: 'download',
        taskId: taskId,
        bookId: bookId,
      );

      await _notificationsPlugin.show(
        notificationId,
        'Downloading',
        bookTitle,
        details,
        payload: payload.encode(),
      );

      return notificationId;
    }, operationName: 'showDownloadStarted');
  }

  /// Update download progress notification
  Future<Result<void>> updateDownloadProgress({
    required String taskId,
    required String bookTitle,
    required int progress,
    required String progressText,
    String? speedText,
    String? bookId,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = _getOrCreateNotificationId(taskId);

      final body = speedText != null
          ? '$progressText • $speedText'
          : progressText;

      final androidDetails = AndroidNotificationDetails(
        AppConstants.downloadChannelId,
        AppConstants.downloadChannelName,
        channelDescription: AppConstants.downloadChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        maxProgress: 100,
        progress: progress.clamp(0, 100),
        actions: [
          const AndroidNotificationAction(
            NotificationActions.pause,
            'Pause',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            NotificationActions.cancel,
            'Cancel',
            showsUserInterface: false,
            cancelNotification: false,
          ),
        ],
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = NotificationPayload(
        type: 'download_progress',
        taskId: taskId,
        bookId: bookId,
      );

      await _notificationsPlugin.show(
        notificationId,
        'Downloading $progress%',
        body,
        details,
        payload: payload.encode(),
      );
    }, operationName: 'updateDownloadProgress');
  }

  /// Show download paused notification
  Future<Result<void>> showDownloadPaused({
    required String taskId,
    required String bookTitle,
    required int progress,
    String? bookId,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = _getOrCreateNotificationId(taskId);

      final androidDetails = AndroidNotificationDetails(
        AppConstants.downloadChannelId,
        AppConstants.downloadChannelName,
        channelDescription: AppConstants.downloadChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: false,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        maxProgress: 100,
        progress: progress.clamp(0, 100),
        actions: [
          const AndroidNotificationAction(
            NotificationActions.resume,
            'Resume',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            NotificationActions.cancel,
            'Cancel',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = NotificationPayload(
        type: 'download_paused',
        taskId: taskId,
        bookId: bookId,
      );

      await _notificationsPlugin.show(
        notificationId,
        'Download Paused',
        '$bookTitle • $progress%',
        details,
        payload: payload.encode(),
      );
    }, operationName: 'showDownloadPaused');
  }

  /// Show download completed notification
  Future<Result<void>> showDownloadCompleted({
    required String taskId,
    required String bookTitle,
    String? bookId,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = _getOrCreateNotificationId(taskId);

      final androidDetails = const AndroidNotificationDetails(
        'epub_download_complete',
        'Download Complete',
        channelDescription: 'Notifications when downloads complete',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        category: AndroidNotificationCategory.status,
        actions: [
          AndroidNotificationAction(
            NotificationActions.open,
            'Open',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = NotificationPayload(
        type: 'download_complete',
        taskId: taskId,
        bookId: bookId,
        action: NotificationActions.open,
      );

      await _notificationsPlugin.show(
        notificationId,
        'Download Complete',
        bookTitle,
        details,
        payload: payload.encode(),
      );

      // Remove from active notifications after delay
      Future.delayed(const Duration(seconds: 5), () {
        _activeNotifications.remove(taskId);
      });
    }, operationName: 'showDownloadCompleted');
  }

  /// Show download failed notification
  Future<Result<void>> showDownloadFailed({
    required String taskId,
    required String bookTitle,
    required String errorMessage,
    bool canRetry = true,
    String? bookId,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = _getOrCreateNotificationId(taskId);

      final actions = <AndroidNotificationAction>[];
      if (canRetry) {
        actions.add(
          const AndroidNotificationAction(
            NotificationActions.retry,
            'Retry',
            showsUserInterface: false,
            cancelNotification: false,
          ),
        );
      }
      actions.add(
        const AndroidNotificationAction(
          NotificationActions.dismiss,
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      );

      final androidDetails = AndroidNotificationDetails(
        'epub_download_error',
        'Download Errors',
        channelDescription: 'Notifications for download errors',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        category: AndroidNotificationCategory.error,
        actions: actions,
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = NotificationPayload(
        type: 'download_failed',
        taskId: taskId,
        bookId: bookId,
      );

      await _notificationsPlugin.show(
        notificationId,
        'Download Failed',
        '$bookTitle: $errorMessage',
        details,
        payload: payload.encode(),
      );
    }, operationName: 'showDownloadFailed');
  }

  /// Show download cancelled notification
  Future<Result<void>> showDownloadCancelled({
    required String taskId,
    required String bookTitle,
  }) async {
    return SafeAsync.run(() async {
      // Just cancel the notification
      await cancelNotification(taskId);
    }, operationName: 'showDownloadCancelled');
  }

  // ===========================================================================
  // BATCH DOWNLOAD NOTIFICATIONS
  // ===========================================================================

  /// Show batch download progress
  Future<Result<void>> showBatchDownloadProgress({
    required int completed,
    required int total,
    required String currentBook,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = AppConstants.downloadNotificationId - 1;

      //final progress = total > 0 ? ((completed / total) * 100).round() : 0;

      final androidDetails = AndroidNotificationDetails(
        AppConstants.downloadChannelId,
        AppConstants.downloadChannelName,
        channelDescription: AppConstants.downloadChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        maxProgress: total,
        progress: completed,
        actions: const [
          AndroidNotificationAction(
            NotificationActions.cancel,
            'Cancel All',
            showsUserInterface: false,
            cancelNotification: false,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);

      final payload = NotificationPayload(
        type: 'batch_download',
        extra: {'completed': completed, 'total': total},
      );

      await _notificationsPlugin.show(
        notificationId,
        'Downloading $completed of $total',
        currentBook,
        details,
        payload: payload.encode(),
      );
    }, operationName: 'showBatchDownloadProgress');
  }

  /// Show batch download completed
  Future<Result<void>> showBatchDownloadCompleted({
    required int successful,
    required int failed,
  }) async {
    return SafeAsync.run(() async {
      final notificationId = AppConstants.downloadNotificationId - 1;

      final title = failed > 0
          ? '$successful downloaded, $failed failed'
          : '$successful books downloaded';

      final androidDetails = const AndroidNotificationDetails(
        'epub_download_complete',
        'Download Complete',
        channelDescription: 'Notifications when downloads complete',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        category: AndroidNotificationCategory.status,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        notificationId,
        'Downloads Complete',
        title,
        details,
      );
    }, operationName: 'showBatchDownloadCompleted');
  }

  // ===========================================================================
  // NOTIFICATION MANAGEMENT
  // ===========================================================================

  /// Cancel notification for a task
  Future<Result<void>> cancelNotification(String taskId) async {
    return SafeAsync.run(() async {
      final notificationId = _activeNotifications[taskId];
      if (notificationId != null) {
        await _notificationsPlugin.cancel(notificationId);
        _activeNotifications.remove(taskId);
      }
    }, operationName: 'cancelNotification');
  }

  /// Cancel all notifications
  Future<Result<void>> cancelAllNotifications() async {
    return SafeAsync.run(() async {
      await _notificationsPlugin.cancelAll();
      _activeNotifications.clear();
    }, operationName: 'cancelAllNotifications');
  }

  /// Get pending notifications
  Future<Result<List<PendingNotificationRequest>>>
  getPendingNotifications() async {
    return SafeAsync.run(() async {
      return await _notificationsPlugin.pendingNotificationRequests();
    }, operationName: 'getPendingNotifications');
  }

  /// Get active notifications (Android only)
  Future<Result<List<ActiveNotification>>> getActiveNotifications() async {
    return SafeAsync.run(() async {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        return await androidPlugin.getActiveNotifications();
      }
      return <ActiveNotification>[];
    }, operationName: 'getActiveNotifications');
  }

  // ===========================================================================
  // ACTION HANDLING
  // ===========================================================================

  /// Add action callback
  void addActionCallback(NotificationCallback callback) {
    _actionCallbacks.add(callback);
  }

  /// Remove action callback
  void removeActionCallback(NotificationCallback callback) {
    _actionCallbacks.remove(callback);
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    try {
      debugPrint(
        'Notification response: ${response.actionId} - ${response.payload}',
      );

      if (response.payload == null || response.payload!.isEmpty) return;

      final payload = NotificationPayload.decode(response.payload!);

      // Add action from response if present
      final finalPayload = response.actionId != null
          ? NotificationPayload(
              type: payload.type,
              taskId: payload.taskId,
              bookId: payload.bookId,
              action: response.actionId,
              extra: payload.extra,
            )
          : payload;

      // Notify listeners
      if (!_actionController.isClosed) {
        _actionController.add(finalPayload);
      }

      // Call callbacks
      for (final callback in _actionCallbacks) {
        try {
          callback(finalPayload);
        } catch (e) {
          debugPrint('Notification callback error: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to handle notification response: $e');
    }
  }

  /// Get or create notification ID for a task
  int _getOrCreateNotificationId(String taskId) {
    if (_activeNotifications.containsKey(taskId)) {
      return _activeNotifications[taskId]!;
    }

    final notificationId = _notificationIdCounter++;
    _activeNotifications[taskId] = notificationId;
    return notificationId;
  }

  // ===========================================================================
  // SIMPLE NOTIFICATIONS
  // ===========================================================================

  /// Show simple notification
  Future<Result<void>> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    return SafeAsync.run(() async {
      const androidDetails = AndroidNotificationDetails(
        'epub_general',
        'General',
        channelDescription: 'General notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        _notificationIdCounter++,
        title,
        body,
        details,
        payload: payload,
      );
    }, operationName: 'showSimpleNotification');
  }

  /// Schedule notification
  Future<Result<void>> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    return SafeAsync.run(() async {
      const androidDetails = AndroidNotificationDetails(
        'epub_scheduled',
        'Scheduled',
        channelDescription: 'Scheduled notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        _notificationIdCounter++,
        title,
        body,
        _convertToTZDateTime(scheduledTime),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    }, operationName: 'scheduleNotification');
  }

  /// Convert DateTime to TZDateTime
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    // Initialize timezone database if not already done
    tz.initializeTimeZones();

    // Use local timezone
    return tz.TZDateTime.from(dateTime, tz.local);
  }
}

/// Background notification response handler (must be top-level)
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint('Background notification response: ${response.actionId}');
  // Handle background actions
  // This is called when app is in background/terminated
}

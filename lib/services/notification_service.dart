import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._internal();

  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      debugPrint('✓ Notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize notifications: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap
  }

  /// Show download progress notification
  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required int progress,
    required int maxProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final percentage = maxProgress > 0
          ? ((progress / maxProgress) * 100).round()
          : 0;

      final androidDetails = AndroidNotificationDetails(
        'download_progress',
        'Download Progress',
        channelDescription: 'Shows download progress',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        channelShowBadge: false,
        icon: '@mipmap/ic_launcher',
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      await _notifications.show(
        id,
        'Downloading: $title',
        '$percentage% complete',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to show progress notification: $e');
    }
  }

  /// Show download complete notification
  Future<void> showDownloadComplete({
    required int id,
    required String title,
    required String filePath,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      const androidDetails = AndroidNotificationDetails(
        'download_complete',
        'Download Complete',
        channelDescription: 'Shows when downloads complete',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        ongoing: false,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notifications.show(
        id,
        'Download Complete',
        title,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: filePath,
      );

      debugPrint('✓ Showed download complete notification: $id');
    } catch (e) {
      debugPrint('⚠️ Failed to show complete notification: $e');
    }
  }

  /// Show download failed notification
  Future<void> showDownloadFailed({
    required int id,
    required String title,
    required String error,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      const androidDetails = AndroidNotificationDetails(
        'download_failed',
        'Download Failed',
        channelDescription: 'Shows when downloads fail',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        ongoing: false,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notifications.show(
        id,
        'Download Failed',
        '$title: $error',
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to show error notification: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('✓ Cancelled notification: $id');
    } catch (e) {
      debugPrint('⚠️ Failed to cancel notification $id: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('✓ Cancelled all notifications');
    } catch (e) {
      debugPrint('⚠️ Failed to cancel all notifications: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidPlugin?.requestNotificationsPermission() ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to request permission: $e');
      return false;
    }
  }
}

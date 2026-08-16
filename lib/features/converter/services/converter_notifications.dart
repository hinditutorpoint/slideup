import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../navigation_service.dart';
import '../../../services/notification_service.dart';
import '../screens/converter_home_screen.dart';
import '../models/conversion_models.dart';
import '../models/conversion_job.dart';
import 'converter_background_worker.dart';

/// Coordinates the two notification surfaces used during conversion:
///  - a persistent Android foreground service when background conversion is
///    enabled (keeps FFmpeg alive when the app is backgrounded), and
///  - regular progress notifications otherwise.
class ConverterNotificationService {
  ConverterNotificationService._();

  static final ConverterNotificationService instance =
      ConverterNotificationService._();

  static const String _fgsChannelId = 'slideup_converter';
  static const int defaultServiceId = 6601;

  bool _fgsInit = false;

  Future<void> _ensureFgsReady() async {
    if (_fgsInit) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _fgsChannelId,
        channelName: 'Background conversions',
        channelDescription:
            'Keeps converting media running in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.initCommunicationPort();
    _fgsInit = true;
  }

  Future<bool> get isForegroundRunning async =>
      FlutterForegroundTask.isRunningService;

  Future<bool> startForeground({
    required ConversionJob job,
    required double fraction,
  }) async {
    await _ensureFgsReady();
    final result = await FlutterForegroundTask.startService(
      serviceId: defaultServiceId,
      serviceTypes: [ForegroundServiceTypes.mediaProcessing],
      notificationTitle: 'Converting ${job.sourceName}',
      notificationText: _progressText(fraction),
      notificationButtons: const [
        NotificationButton(id: FgsAction.cancel, text: 'Cancel'),
        NotificationButton(id: FgsAction.open, text: 'Open'),
      ],
      callback: conversionBackgroundTask,
    );
    return result.isSuccess;
  }

  Future<void> updateForeground({
    required ConversionJob job,
    required double fraction,
  }) async {
    if (!(await isForegroundRunning)) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Converting ${job.sourceName}',
      notificationText: _progressText(fraction),
    );
  }

  Future<void> stopForeground() async {
    if (!(await isForegroundRunning)) return;
    await FlutterForegroundTask.stopService();
  }

  static String _progressText(double fraction) {
    final percent = (fraction.clamp(0, 1) * 100).round();
    return '$percent% complete';
  }

  // ───────────────────────── Local notifications ─────────────────────────

  Future<void> showProgress({
    required ConversionJob job,
    required double fraction,
  }) {
    return NotificationService().showConversionProgress(
      id: job.notificationId,
      title: job.sourceName,
      progress: (fraction.clamp(0, 1) * 1000).round(),
      maxProgress: 1000,
    );
  }

  Future<void> showResult({
    required ConversionJob job,
    required bool success,
  }) {
    return NotificationService().showConversionResult(
      id: job.notificationId,
      title: '${job.sourceName} → ${job.settings.format.label}',
      success: success,
      outputPath: job.outputPath,
    );
  }

  Future<void> dismiss(ConversionJob job) {
    return NotificationService().cancelNotification(job.notificationId);
  }

  /// Opens the converter home screen from a notification/FGS action.
  static void openConverterScreen() {
    try {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/converter-home'),
          builder: (_) => const ConverterHomeScreen(),
        ),
      );
    } catch (_) {}
  }
}

extension on ServiceRequestResult {
  bool get isSuccess => this is ServiceRequestSuccess;
}
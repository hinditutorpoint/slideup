import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Actions that can be signaled through the foreground service notification.
class FgsAction {
  static const String cancel = 'cancel';
  static const String open = 'open';
}

/// Top-level entry point registered as the service callback. Runs in the
/// plugin's background isolate; keep it dependency-free.
@pragma('vm:entry-point')
void conversionBackgroundTask() {
  FlutterForegroundTask.setTaskHandler(ConversionTaskHandler());
}

/// Bridges foreground-service notification button presses back to the main
/// isolate so the UI-independent conversion manager can react (and FFmpeg is
/// actually cancelled, not just hidden).
class ConversionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{'action': id});
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'action': FgsAction.open,
    });
  }

  @override
  void onReceiveData(Object data) {}
}
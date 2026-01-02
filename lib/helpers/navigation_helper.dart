import '../navigation_service.dart';

class NavigationHelper {
  static void navigateToAudioPlayer() {
    rootNavigatorKey.currentState?.pushNamed('/audio-player');
  }

  static void pop() {
    rootNavigatorKey.currentState?.pop();
  }

  static void popUntilHome() {
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}

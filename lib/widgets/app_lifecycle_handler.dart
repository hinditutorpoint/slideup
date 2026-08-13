import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mini_player_provider.dart';
import '../features/epub_reader/providers/epub_provider.dart';
import '../providers/intent_handler_provider.dart';
import '../services/intent_handler_service.dart';
import '../screens/intent_receiver_screen.dart';
import '../screens/auth_screen.dart';
import '../services/security_service.dart';
import '../navigation_service.dart';

class AppLifecycleHandler extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleHandler({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleHandler> createState() =>
      _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends ConsumerState<AppLifecycleHandler>
    with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('📱 App lifecycle state: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _refreshDownloads();
        _onAppResumed();
        if (_wasBackgrounded) {
          _wasBackgrounded = false;
          _relockOnResume();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _wasBackgrounded = true;
        ref.read(miniPlayerProvider.notifier).setAppForegroundState(false);
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        _wasBackgrounded = true;
        ref.read(miniPlayerProvider.notifier).setAppForegroundState(false);
        break;
    }
  }

  Future<void> _relockOnResume() async {
    try {
      final hasLock = await SecurityService.instance.hasAppLock();
      if (!hasLock) return;

      final navigator = rootNavigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return;

      final topRoute = ModalRoute.of(navigator.context);
      if (topRoute?.settings.name == '/auth' ||
          topRoute is PageRoute && topRoute.settings.name == '/auth') {
        return;
      }

      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/auth'),
            builder: (context) => const AuthScreen(isSetup: false),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Re-lock error: $e');
    }
  }

  void _refreshDownloads() {
    try {
      // Check if provider is available
      ref.read(downloadProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Failed to refresh downloads: $e');
    }
  }

  Future<void> _onAppResumed() async {
    // Refresh download state to sync with background downloads
    debugPrint('📱 App resumed - checking for pending intents...');

    // Update mini player state
    ref.read(miniPlayerProvider.notifier).setAppForegroundState(true);

    // Check for pending intents that might have been missed
    await _checkPendingIntent();
  }

  Future<void> _checkPendingIntent() async {
    try {
      final pendingIntent = await IntentHandlerService.getPendingIntent();

      if (pendingIntent != null && pendingIntent.isNotEmpty) {
        debugPrint('📂 Found pending intent on resume: $pendingIntent');

        // Update provider
        ref.read(intentProvider.notifier).setOpenedFile(pendingIntent);

        // Navigate to intent receiver
        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => IntentReceiverScreen(filePath: pendingIntent),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error checking pending intent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

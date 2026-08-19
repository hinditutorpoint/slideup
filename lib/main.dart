import 'dart:async';
import 'dart:io' show File, FileMode, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'features/speaker_player/services/background_chapter_generator.dart';

import 'features/epub_reader/services/worker_dispatcher.dart';

import 'package:slideup/widgets/audio_player_overlay.dart';
import 'features/video_player/widgets/pip_overlay.dart';
import 'screens/splash_screen.dart';
import 'screens/intent_receiver_screen.dart';
import 'widgets/audio_player_wrapper.dart';
import 'widgets/app_lifecycle_handler.dart';
import 'providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'services/database_service.dart';
import 'services/cache_cleanup_service.dart';
import 'services/audio_service.dart';
import 'services/intent_handler_service.dart';
import 'services/notification_service.dart' as notification_service;
import 'providers/audio_handler_provider.dart';
import 'providers/intent_handler_provider.dart';
import 'features/converter/services/conversion_manager.dart';
import 'features/converter/widgets/converter_global_indicator.dart';
import 'features/epub_reader/models/epub_book.dart';
import 'features/epub_reader/models/epub_chapter.dart';
import 'features/epub_reader/models/download_task.dart';
import 'features/epub_reader/models/reading_progress.dart';
import 'features/speaker_player/models/download_model.dart';
import 'features/epub_reader/providers/epub_provider.dart';
import 'features/speaker_player/models/tts_audio_cache.dart';
import '/features/speaker_player/screens/models_screen.dart';
import 'navigation_service.dart';

Future<void> main() async {
  // ------------------------------------------------------------
  // Global error handling: keep the app alive and log everything.
  // ------------------------------------------------------------
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logGlobalError('FlutterError: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _logGlobalError('Platform error: $error\n$stackTrace');
    return true; // Swallow the error so the app keeps running.
  };

  await runZonedGuarded(() => _bootstrapApp(), (error, stackTrace) {
    _logGlobalError('Uncaught zone error: $error\n$stackTrace');
  });
}

Future<void> _bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  await Hive.openBox('settings');

  Hive
    ..registerAdapter(LinkTypeAdapter())
    ..registerAdapter(AnchorTypeAdapter())
    ..registerAdapter(DownloadStatusAdapter())
    ..registerAdapter(HighlightColorAdapter())
    ..registerAdapter(NoteTypeAdapter())
    ..registerAdapter(TranslationProviderAdapter())
    ..registerAdapter(TranslationDisplayModeAdapter())
    ..registerAdapter(ModelDownloadStatusAdapter())
    ..registerAdapter(SherpaModelTypeAdapter())
    ..registerAdapter(ChapterImageAdapter())
    ..registerAdapter(ChapterLinkAdapter())
    ..registerAdapter(ChapterAnchorAdapter())
    ..registerAdapter(TocEntryAdapter())
    ..registerAdapter(EpubChapterMetaAdapter())
    ..registerAdapter(BookmarkAdapter())
    ..registerAdapter(HighlightAdapter())
    ..registerAdapter(NoteAdapter())
    ..registerAdapter(ReadingSessionAdapter())
    ..registerAdapter(TextTranslationAdapter())
    ..registerAdapter(ChapterTranslationAdapter())
    ..registerAdapter(TranslationSettingsAdapter())
    ..registerAdapter(EpubChapterAdapter())
    ..registerAdapter(EpubBookAdapter())
    ..registerAdapter(ReadingProgressAdapter())
    ..registerAdapter(DownloadTaskAdapter())
    ..registerAdapter(DownloadedModelAdapter())
    ..registerAdapter(TtsAudioCacheAdapter());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  final AudioPlayerHandler audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.slideup.mediaplayer.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
    ),
  );

  // Non-blocking background initializations for instant app launch
  unawaited(_initBackgroundServices());

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const SlideupMediaPlayerApp(),
    ),
  );
}

Future<void> _initBackgroundServices() async {
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Workmanager().initialize(callbackDispatcher);
    }
  } catch (e) {
    debugPrint('Workmanager init error: $e');
  }

  try {
    await DatabaseService.instance.database;
  } catch (e) {
    debugPrint('Database init error: $e');
  }

  try {
    await notification_service.NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  try {
    await IntentHandlerService.initialize();
  } catch (e) {
    debugPrint('IntentHandler error: $e');
  }

  try {
    await BackgroundChapterGenerator.instance.initialize();
  } catch (e) {
    debugPrint('BackgroundChapterGenerator error: $e');
  }

  try {
    await ConversionManager.instance.initializeAndRecover();
  } catch (e) {
    debugPrint('Converter init error: $e');
  }

  try {
    await CacheCleanupService.instance.cleanupOrphanedTempFiles();
  } catch (e) {
    debugPrint('Cache cleanup error: $e');
  }
}

void _logGlobalError(String message) {
  try {
    debugPrint('🛑 $message');
    getApplicationDocumentsDirectory().then((dir) {
      try {
        final file = File('${dir.path}/error_log.txt');
        file.writeAsStringSync(
          '${DateTime.now().toIso8601String()}\n$message\n\n',
          mode: FileMode.append,
        );
      } catch (_) {
        // Logging must never crash the app.
      }
    });
  } catch (_) {
    // Logging must never crash the app.
  }
}

class SlideupMediaPlayerApp extends ConsumerStatefulWidget {
  const SlideupMediaPlayerApp({super.key});

  @override
  ConsumerState<SlideupMediaPlayerApp> createState() =>
      _SlideupMediaPlayerAppState();
}

class _SlideupMediaPlayerAppState extends ConsumerState<SlideupMediaPlayerApp> {
  bool _checkedIntent = false;
  StreamSubscription<String?>? _intentSub;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    IntentHandlerService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Small delay to ensure Flutter is fully ready
    await Future.delayed(const Duration(milliseconds: 100));

    // Check for initial intent
    await _checkInitialIntent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(initializationProvider.notifier).initialize();
    });
    // Start listening for new intents
    _listenForIntents();

    if (mounted) {
      setState(() {
        _checkedIntent = true;
      });
    }
  }

  Future<void> _checkInitialIntent() async {
    try {
      final initialIntent = await IntentHandlerService.getInitialIntent();

      if (initialIntent != null) {
        ref.read(intentProvider.notifier).setOpenedFile(initialIntent);
      } else {
        debugPrint('📂 No initial file intent');
      }
    } catch (e) {
      debugPrint('⚠️ Error getting initial intent: $e');
    }
  }

  void _listenForIntents() {
    _intentSub?.cancel();
    _intentSub = IntentHandlerService.intentStream.listen(
      (filePath) {
        if (filePath != null && filePath.isNotEmpty && mounted) {
          debugPrint('📂 New file received while running: $filePath');
          ref.read(intentProvider.notifier).setOpenedFile(filePath);

          // Navigate to intent receiver
          rootNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => IntentReceiverScreen(filePath: filePath),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      },
      onError: (error) {
        debugPrint('⚠️ Intent stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(initializationProvider);
    if (!_checkedIntent &&
        initState.isInitializing &&
        !initState.isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF1A1A2E),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    final themeAsync = ref.watch(themeProvider);
    final intentState = ref.watch(intentProvider);

    return themeAsync.when(
      loading: () {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Color(0xFF1A1A2E),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        );
      },
      error: (e, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: Text('Theme load error: $e'))),
        );
      },
      data: (themeState) {
        final brightness = MediaQuery.platformBrightnessOf(context);

        final ThemeData theme = themeState.useSystemTheme
            ? AppTheme.getTheme(AppThemeMode.system, brightness)
            : AppTheme.getTheme(themeState.themeMode, brightness);

        final hasIntentFile =
            intentState.openedFilePath != null &&
            intentState.openedFilePath!.isNotEmpty;

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'Slideup Media Player',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: AppLifecycleHandler(
            child: hasIntentFile
                ? IntentReceiverScreen(filePath: intentState.openedFilePath!)
                : const SplashScreen(),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: PiPOverlay(
                child: AudioPlayerOverlay(
                  child: ConverterGlobalIndicator(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/audio-player':
                return MaterialPageRoute(
                  builder: (_) => const AudioPlayerWrapper(),
                  settings: settings,
                );
              case '/intent-receiver':
                return MaterialPageRoute(
                  builder: (_) => IntentReceiverScreen(
                    filePath: settings.arguments as String,
                  ),
                  settings: settings,
                );
              case '/models':
                return MaterialPageRoute(
                  builder: (_) => const ModelsScreen(),
                  settings: settings,
                );
              default:
                return null;
            }
          },
        );
      },
    );
  }
}

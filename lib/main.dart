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
import 'services/audio_service.dart';
import 'services/intent_handler_service.dart';
import 'services/notification_service.dart' as notification_service;
import 'providers/audio_handler_provider.dart';
import 'providers/intent_handler_provider.dart';
import 'features/video_player/video_player_init.dart';
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
    _logGlobalError(
      'FlutterError: ${details.exception}\n${details.stack}',
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _logGlobalError('Platform error: $error\n$stackTrace');
    return true; // Swallow the error so the app keeps running.
  };

  await runZonedGuarded(
    () => _bootstrapApp(),
    (error, stackTrace) {
      _logGlobalError('Uncaught zone error: $error\n$stackTrace');
    },
  );
}

Future<void> _bootstrapApp() async {
  // Ensure the binding is initialized in the SAME zone as runApp
  // (otherwise Flutter throws "Zone mismatch").
  WidgetsFlutterBinding.ensureInitialized();
  // ------------------------------------------------------------
  // Workmanager: MUST be initialized in main on Android/iOS
  // ------------------------------------------------------------
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Workmanager().initialize(callbackDispatcher);
      debugPrint('Workmanager initialized in main()');
    } catch (e, st) {
      debugPrint('Workmanager init failed in main: $e\n$st');
    }
  } else {
    debugPrint(
      'Workmanager not supported on this platform; skipping initialization.',
    );
  }

  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  await Hive.openBox('settings');
  // Step 1: Enums first (no dependencies)
  Hive
    // Step 1: Existing enums
    ..registerAdapter(LinkTypeAdapter()) // typeId: 6
    ..registerAdapter(AnchorTypeAdapter()) // typeId: 8
    ..registerAdapter(DownloadStatusAdapter()) // typeId: 10
    ..registerAdapter(HighlightColorAdapter()) // typeId: 16
    ..registerAdapter(NoteTypeAdapter()) // typeId: 17
    ..registerAdapter(TranslationProviderAdapter()) // typeId: 21
    ..registerAdapter(TranslationDisplayModeAdapter()) // typeId: 22
    // NEW: Model download enums
    ..registerAdapter(ModelDownloadStatusAdapter()) // typeId: 23
    ..registerAdapter(SherpaModelTypeAdapter()) // typeId: 24
    // Step 2: Existing simple classes
    ..registerAdapter(ChapterImageAdapter()) // typeId: 4
    ..registerAdapter(ChapterLinkAdapter()) // typeId: 5
    ..registerAdapter(ChapterAnchorAdapter()) // typeId: 7
    ..registerAdapter(TocEntryAdapter()) // typeId: 2
    ..registerAdapter(EpubChapterMetaAdapter()) // typeId: 1
    ..registerAdapter(BookmarkAdapter()) // typeId: 12
    ..registerAdapter(HighlightAdapter()) // typeId: 13
    ..registerAdapter(NoteAdapter()) // typeId: 14
    ..registerAdapter(ReadingSessionAdapter()) // typeId: 15
    ..registerAdapter(TextTranslationAdapter()) // typeId: 18
    ..registerAdapter(ChapterTranslationAdapter()) // typeId: 19
    ..registerAdapter(TranslationSettingsAdapter()) // typeId: 20
    // Step 3: Existing complex classes
    ..registerAdapter(EpubChapterAdapter()) // typeId: 3
    ..registerAdapter(EpubBookAdapter()) // typeId: 0
    ..registerAdapter(ReadingProgressAdapter()) // typeId: 11
    ..registerAdapter(DownloadTaskAdapter()) // typeId: 9
    // NEW: Model download class
    ..registerAdapter(DownloadedModelAdapter()) // typeId: 25
    ..registerAdapter(TtsAudioCacheAdapter());

  await DatabaseService.instance.database;

  await notification_service.NotificationService().initialize();

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

  await VideoPlayerInit.initialize();

  // Initialize intent handler BEFORE running app
  await IntentHandlerService.initialize();

  await BackgroundChapterGenerator.instance.initialize();

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const SlideupMediaPlayerApp(),
    ),
  );
}

void _logGlobalError(String message) {
  try {
    debugPrint('🛑 $message');
    getApplicationDocumentsDirectory().then((dir) {
      try {
        final file = File(
          '${dir.path}/error_log.txt',
        );
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
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
    IntentHandlerService.intentStream.listen(
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
                  child: child ?? const SizedBox.shrink(),
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

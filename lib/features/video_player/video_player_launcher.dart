import 'package:flutter/material.dart';

// Import your MediaFile model
import '../../../../models/media_file.dart';
import '../../../navigation_service.dart';

import 'models/player_media.dart';
import 'video_player_screen.dart';

/// Video Player Launcher
///
/// Smart launcher that works in ANY condition:
///
/// ```dart
/// // ✅ Method 1: Direct call (handles navigation internally)
/// VideoPlayerLauncher.open(context, files: videos, index: 3);
///
/// // ✅ Method 2: Get widget for custom navigation
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VideoPlayerLauncher.screen(files: videos, index: 3),
/// ));
///
/// // ✅ Method 3: Use with _safeNavigate
/// _safeNavigate(VideoPlayerLauncher.screen(files: videos, index: 3));
///
/// // ✅ Method 4: Without context (global)
/// VideoPlayerLauncher.openGlobal(files: videos, index: 3);
///
/// // ✅ Method 5: Smart (auto-detects)
/// VideoPlayerLauncher.smart(source: videos, index: 3, context: context);
/// ```
class VideoPlayerLauncher {
  VideoPlayerLauncher._();

  static GlobalKey<NavigatorState> get navigatorKey => rootNavigatorKey;
  static NavigatorState? get _navigator => rootNavigatorKey.currentState;
  static bool get isGlobalNavigationAvailable => _navigator != null;

  // ═══════════════════════════════════════════════════════
  // ✅ SCREEN METHOD - Returns Widget (Use for Navigator.push)
  // ═══════════════════════════════════════════════════════

  /// Get player screen widget - USE THIS FOR Navigator.push()
  ///
  /// Examples:
  /// ```dart
  /// // In Navigator.push
  /// Navigator.push(context, MaterialPageRoute(
  ///   builder: (_) => VideoPlayerLauncher.screen(files: videos, index: 3),
  /// ));
  ///
  /// // With _safeNavigate
  /// _safeNavigate(VideoPlayerLauncher.screen(file: video));
  ///
  /// // Single file
  /// VideoPlayerLauncher.screen(file: myFile)
  ///
  /// // List at index
  /// VideoPlayerLauncher.screen(files: videos, index: 3)
  ///
  /// // File from list (auto-finds index)
  /// VideoPlayerLauncher.screen(file: video, files: allVideos)
  ///
  /// // URL
  /// VideoPlayerLauncher.screen(url: 'https://...')
  ///
  /// // URLs at index
  /// VideoPlayerLauncher.screen(urls: urlList, index: 2)
  /// ```
  static Widget screen({
    MediaFile? file,
    List<MediaFile>? files,
    int index = 0,
    String? url,
    List<String>? urls,
    List<String>? titles,
    bool autoPlay = true,
    bool fullscreen = false,
  }) {
    try {
      final playlist = _buildPlaylist(
        file: file,
        files: files,
        index: index,
        url: url,
        urls: urls,
        titles: titles,
      );

      if (playlist == null || playlist.isEmpty) {
        debugPrint('❌ VideoPlayerLauncher.screen: No valid media');
        return _buildErrorWidget('No valid media provided');
      }

      return VideoPlayerScreen(
        playlist: playlist,
        autoPlay: autoPlay,
        startFullscreen: fullscreen,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerLauncher.screen error: $e');
      debugPrint('Stack: $stackTrace');
      return _buildErrorWidget('Error: $e');
    }
  }

  /// Shorthand for single file
  static Widget file(
    MediaFile mediaFile, {
    bool autoPlay = true,
    bool fullscreen = false,
  }) => screen(file: mediaFile, autoPlay: autoPlay, fullscreen: fullscreen);

  /// Shorthand for files at index
  static Widget fileList(
    List<MediaFile> mediaFiles, {
    int index = 0,
    bool autoPlay = true,
    bool fullscreen = false,
  }) => screen(
    files: mediaFiles,
    index: index,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  /// Shorthand for file from list
  static Widget fileFromList(
    MediaFile mediaFile,
    List<MediaFile> allFiles, {
    bool autoPlay = true,
    bool fullscreen = false,
  }) => screen(
    file: mediaFile,
    files: allFiles,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  /// Shorthand for URL
  static Widget urlScreen(
    String videoUrl, {
    String? title,
    bool autoPlay = true,
    bool fullscreen = false,
  }) => screen(
    url: videoUrl,
    titles: title != null ? [title] : null,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  /// Shorthand for URLs at index
  static Widget urlList(
    List<String> videoUrls, {
    List<String>? titles,
    int index = 0,
    bool autoPlay = true,
    bool fullscreen = false,
  }) => screen(
    urls: videoUrls,
    titles: titles,
    index: index,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  // ═══════════════════════════════════════════════════════
  // ✅ OPEN METHOD - Handles navigation internally
  // ═══════════════════════════════════════════════════════

  /// Open player with internal navigation
  ///
  /// Examples:
  /// ```dart
  /// // Simple call - handles everything
  /// VideoPlayerLauncher.open(context, files: videos, index: 3);
  /// VideoPlayerLauncher.open(context, file: video);
  /// VideoPlayerLauncher.open(context, url: 'https://...');
  /// ```
  static Future<void> open(
    BuildContext context, {
    MediaFile? file,
    List<MediaFile>? files,
    int index = 0,
    String? url,
    List<String>? urls,
    List<String>? titles,
    bool autoPlay = true,
    bool fullscreen = false,
    bool replace = false,
  }) async {
    try {
      if (!context.mounted) {
        debugPrint('⚠️ Context not mounted, trying global');
        await openGlobal(
          file: file,
          files: files,
          index: index,
          url: url,
          urls: urls,
          titles: titles,
          autoPlay: autoPlay,
          fullscreen: fullscreen,
          replace: replace,
        );
        return;
      }

      final playerScreen = screen(
        file: file,
        files: files,
        index: index,
        url: url,
        urls: urls,
        titles: titles,
        autoPlay: autoPlay,
        fullscreen: fullscreen,
      );

      if (replace) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => playerScreen),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => playerScreen),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerLauncher.open error: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Open without context (uses global navigator)
  static Future<bool> openGlobal({
    MediaFile? file,
    List<MediaFile>? files,
    int index = 0,
    String? url,
    List<String>? urls,
    List<String>? titles,
    bool autoPlay = true,
    bool fullscreen = false,
    bool replace = false,
  }) async {
    if (_navigator == null) {
      debugPrint(
        '❌ Global navigator not available. Set VideoPlayerLauncher.navigatorKey in MaterialApp',
      );
      return false;
    }

    try {
      final playerScreen = screen(
        file: file,
        files: files,
        index: index,
        url: url,
        urls: urls,
        titles: titles,
        autoPlay: autoPlay,
        fullscreen: fullscreen,
      );

      if (replace) {
        await _navigator!.pushReplacement(
          MaterialPageRoute(builder: (_) => playerScreen),
        );
      } else {
        await _navigator!.push(MaterialPageRoute(builder: (_) => playerScreen));
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerLauncher.openGlobal error: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SMART METHOD - Auto-detects best approach
  // ═══════════════════════════════════════════════════════

  /// Smart open - uses context if available, otherwise global
  ///
  /// Can accept any source type:
  /// - MediaFile
  /// - List<MediaFile>
  /// - String (URL)
  /// - List<String> (URLs)
  ///
  /// Examples:
  /// ```dart
  /// VideoPlayerLauncher.smart(source: video, context: context);
  /// VideoPlayerLauncher.smart(source: videos, index: 3, context: context);
  /// VideoPlayerLauncher.smart(source: 'https://...', context: context);
  /// VideoPlayerLauncher.smart(source: videos, index: 3); // Uses global
  /// ```
  static Future<bool> smart({
    dynamic source,
    MediaFile? file,
    List<MediaFile>? files,
    int index = 0,
    String? url,
    List<String>? urls,
    List<String>? titles,
    BuildContext? context,
    bool autoPlay = true,
    bool fullscreen = false,
    bool replace = false,
  }) async {
    try {
      // Handle dynamic source
      if (source != null) {
        if (source is MediaFile) {
          file = source;
        } else if (source is List<MediaFile>) {
          files = source;
        } else if (source is String) {
          url = source;
        } else if (source is List<String>) {
          urls = source;
        }
      }

      // Try with context first
      if (context != null && context.mounted) {
        await open(
          context,
          file: file,
          files: files,
          index: index,
          url: url,
          urls: urls,
          titles: titles,
          autoPlay: autoPlay,
          fullscreen: fullscreen,
          replace: replace,
        );
        return true;
      }

      // Fall back to global
      return await openGlobal(
        file: file,
        files: files,
        index: index,
        url: url,
        urls: urls,
        titles: titles,
        autoPlay: autoPlay,
        fullscreen: fullscreen,
        replace: replace,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerLauncher.smart error: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ INTERNAL METHODS
  // ═══════════════════════════════════════════════════════

  static PlayerPlaylist? _buildPlaylist({
    MediaFile? file,
    List<MediaFile>? files,
    int index = 0,
    String? url,
    List<String>? urls,
    List<String>? titles,
  }) {
    try {
      // File with list context (auto-find index)
      if (file != null && files != null && files.isNotEmpty) {
        int foundIndex = files.indexWhere((f) => f.id == file.id);
        if (foundIndex == -1) {
          foundIndex = files.indexWhere((f) => f.path == file.path);
        }
        if (foundIndex == -1) {
          debugPrint('⚠️ File not found in list, adding at beginning');
          files = [file, ...files];
          foundIndex = 0;
        }
        return PlayerPlaylist.fromMediaFiles(files, startIndex: foundIndex);
      }

      // Files with index
      if (files != null && files.isNotEmpty) {
        final safeIndex = index.clamp(0, files.length - 1);
        if (index != safeIndex) {
          debugPrint('⚠️ Index $index out of range, using $safeIndex');
        }
        return PlayerPlaylist.fromMediaFiles(files, startIndex: safeIndex);
      }

      // Single file
      if (file != null) {
        return PlayerPlaylist.single(file);
      }

      // URL with list context
      if (url != null && urls != null && urls.isNotEmpty) {
        final foundIndex = urls.indexOf(url);
        final startIndex = foundIndex >= 0 ? foundIndex : 0;
        return PlayerPlaylist.fromUrls(
          urls,
          titles: titles,
          startIndex: startIndex,
        );
      }

      // URLs with index
      if (urls != null && urls.isNotEmpty) {
        final safeIndex = index.clamp(0, urls.length - 1);
        return PlayerPlaylist.fromUrls(
          urls,
          titles: titles,
          startIndex: safeIndex,
        );
      }

      // Single URL
      if (url != null && url.isNotEmpty) {
        return PlayerPlaylist.fromUrls([url], titles: titles);
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ _buildPlaylist error: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }

  static Widget _buildErrorWidget(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UTILITY METHODS
  // ═══════════════════════════════════════════════════════

  static bool isPlayableVideo(MediaFile file) {
    try {
      if (file.type != MediaType.video) return false;
      final path = file.path.toLowerCase();
      const exts = [
        '.mp4',
        '.mkv',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.webm',
        '.m4v',
        '.3gp',
        '.ts',
        '.m3u8',
      ];
      return exts.any((ext) => path.endsWith(ext));
    } catch (e) {
      return false;
    }
  }

  static List<MediaFile> filterPlayableVideos(List<MediaFile> files) {
    try {
      return files.where((f) => isPlayableVideo(f)).toList();
    } catch (e) {
      return [];
    }
  }

  static int findFileIndex(MediaFile file, List<MediaFile> files) {
    int idx = files.indexWhere((f) => f.id == file.id);
    if (idx >= 0) return idx;
    idx = files.indexWhere((f) => f.path == file.path);
    return idx >= 0 ? idx : -1;
  }
}

// ═══════════════════════════════════════════════════════
// ✅ EXTENSIONS
// ═══════════════════════════════════════════════════════

extension MediaFileVideoPlayer on MediaFile {
  /// Get player screen widget
  Widget playerScreen({bool autoPlay = true, bool fullscreen = false}) =>
      VideoPlayerLauncher.file(
        this,
        autoPlay: autoPlay,
        fullscreen: fullscreen,
      );

  /// Open player with context
  Future<void> openPlayer(BuildContext context, {bool autoPlay = true}) async =>
      await VideoPlayerLauncher.open(context, file: this, autoPlay: autoPlay);

  /// Open player without context
  Future<bool> openPlayerGlobal({bool autoPlay = true}) async =>
      await VideoPlayerLauncher.openGlobal(file: this, autoPlay: autoPlay);

  /// Smart open
  Future<bool> smartOpen({BuildContext? context, bool autoPlay = true}) async =>
      await VideoPlayerLauncher.smart(
        file: this,
        context: context,
        autoPlay: autoPlay,
      );
}

extension MediaFileListVideoPlayer on List<MediaFile> {
  /// Get player screen at index
  Widget playerScreen({
    int index = 0,
    bool autoPlay = true,
    bool fullscreen = false,
  }) => VideoPlayerLauncher.fileList(
    this,
    index: index,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  /// Get player screen for specific file
  Widget playerScreenFor(
    MediaFile file, {
    bool autoPlay = true,
    bool fullscreen = false,
  }) => VideoPlayerLauncher.fileFromList(
    file,
    this,
    autoPlay: autoPlay,
    fullscreen: fullscreen,
  );

  /// Open player at index
  Future<void> openPlayer(
    BuildContext context, {
    int index = 0,
    bool autoPlay = true,
  }) async => await VideoPlayerLauncher.open(
    context,
    files: this,
    index: index,
    autoPlay: autoPlay,
  );

  /// Open player for specific file
  Future<void> openPlayerFor(
    BuildContext context,
    MediaFile file, {
    bool autoPlay = true,
  }) async => await VideoPlayerLauncher.open(
    context,
    file: file,
    files: this,
    autoPlay: autoPlay,
  );

  /// Open without context at index
  Future<bool> openPlayerGlobal({int index = 0, bool autoPlay = true}) async =>
      await VideoPlayerLauncher.openGlobal(
        files: this,
        index: index,
        autoPlay: autoPlay,
      );

  /// Smart open at index
  Future<bool> smartOpen({
    BuildContext? context,
    int index = 0,
    bool autoPlay = true,
  }) async => await VideoPlayerLauncher.smart(
    files: this,
    index: index,
    context: context,
    autoPlay: autoPlay,
  );

  /// Get playable videos only
  List<MediaFile> get playableVideos =>
      VideoPlayerLauncher.filterPlayableVideos(this);

  /// Find index of file
  int findIndex(MediaFile file) =>
      VideoPlayerLauncher.findFileIndex(file, this);
}

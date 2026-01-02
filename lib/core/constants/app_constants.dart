import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Slideup Media Player';
  static const String appVersion = '1.0.0';
  static const String appPackage = 'com.slideup.mediaplayer';

  // Database
  static const String databaseName = 'slideup_media.db';
  static const int databaseVersion = 1;

  // Hive Boxes
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';

  // Preferences Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyThemeMode = 'theme_mode';
  static const String keyVideoQuality = 'video_quality';
  static const String keyAutoPlayNext = 'auto_play_next';
  static const String keyBackgroundAudio = 'background_audio';
  static const String keyVideoPopup = 'video_popup';

  // Supported Video Formats
  static const List<String> videoFormats = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    '3gp',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
    'ts',
    'm3u8',
    'mpd',
  ];

  // Supported Audio Formats
  static const List<String> audioFormats = [
    'mp3',
    'wav',
    'flac',
    'aac',
    'm4a',
    'ogg',
    'wma',
    'opus',
  ];

  // Supported Document Formats
  static const List<String> documentFormats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
  ];

  // Network Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double defaultElevation = 4.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Thumbnail Settings
  static const int thumbnailMaxWidth = 256;
  static const int thumbnailQuality = 75;

  // Video Player Settings
  static const Duration seekDuration = Duration(seconds: 10);
  static const double playbackSpeedMin = 0.25;
  static const double playbackSpeedMax = 2.0;

  // Recent Files Limit
  static const int recentFilesLimit = 50;

  // Max File Name Length
  static const int maxFileNameLength = 100;

  // ==========================================================================
  // EPUB CONSTANTS
  // ==========================================================================
  static const String epubExtension = '.epub';
  static const String epubMimeType = 'application/epub+zip';
  static const List<String> supportedFormats = ['.epub'];

  // ==========================================================================
  // DOWNLOAD CONSTANTS
  // ==========================================================================
  static const int downloadChunkSize = 1024 * 1024; // 1MB chunks
  static const int maxConcurrentDownloads = 3;
  static const int downloadRetryAttempts = 3;
  static const Duration downloadRetryDelay = Duration(seconds: 2);
  static const Duration downloadTimeout = Duration(minutes: 30);

  // ==========================================================================
  // MEMORY CONSTANTS
  // ==========================================================================
  static const int maxMemoryUsageMB = 150;
  static const int lowMemoryThresholdMB = 50;
  static const int criticalMemoryThresholdMB = 20;
  static const int maxCachedChapters = 5;
  static const int maxCachedImages = 20;
  static const int imageCacheSizeMB = 100;

  // ==========================================================================
  // ISOLATE CONSTANTS
  // ==========================================================================
  static const int maxIsolatePoolSize = 4;
  static const Duration isolateTimeout = Duration(minutes: 5);
  static const Duration isolateKeepAlive = Duration(minutes: 2);

  // ==========================================================================
  // CACHE CONSTANTS
  // ==========================================================================
  static const Duration cacheMaxAge = Duration(days: 30);
  static const int maxCacheSizeMB = 500;
  static const String epubCacheDir = 'epub_cache';
  static const String downloadDir = 'downloads';
  static const String tempDir = 'temp';

  // ==========================================================================
  // READER CONSTANTS
  // ==========================================================================
  static const double defaultFontSize = 16.0;
  static const double minFontSize = 10.0;
  static const double maxFontSize = 32.0;
  static const double fontSizeStep = 2.0;
  static const double defaultLineHeight = 1.5;
  static const double minLineHeight = 1.0;
  static const double maxLineHeight = 3.0;
  static const double defaultMargin = 16.0;

  // ==========================================================================
  // NOTIFICATION CONSTANTS
  // ==========================================================================
  static const String downloadChannelId = 'epub_download_channel';
  static const String downloadChannelName = 'EPUB Downloads';
  static const String downloadChannelDesc = 'Notifications for EPUB downloads';
  static const int downloadNotificationId = 1000;

  // ==========================================================================
  // BACKGROUND SERVICE CONSTANTS
  // ==========================================================================
  static const String backgroundTaskName = 'epubBackgroundTask';
  static const Duration backgroundTaskFrequency = Duration(hours: 1);
  static const Duration minBackgroundInterval = Duration(minutes: 15);

  // ==========================================================================
  // DATABASE CONSTANTS
  // ==========================================================================
  static const String databaseEpubName = 'epub_reader.db';
  static const int databaseEpubVersion = 1;
  static const String hiveBooksBox = 'epub_books';
  static const String hiveProgressBox = 'reading_progress';
  static const String hiveSettingsBox = 'reader_settings';
  static const String hiveDownloadsBox = 'downloads';

  // ==========================================================================
  // UI CONSTANTS
  // ==========================================================================
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double cardElevation = 2.0;

  // ==========================================================================
  // PAGINATION CONSTANTS
  // ==========================================================================
  static const int chapterPreloadCount = 2;
  static const int pageBufferSize = 3;
  static const int searchResultsLimit = 100;

  // ==========================================================================
  // ERROR MESSAGES
  // ==========================================================================
  static const String errorGeneric = 'An unexpected error occurred';
  static const String errorNetwork =
      'Network error. Please check your connection';
  static const String errorDownload = 'Download failed. Please try again';
  static const String errorParsing = 'Failed to parse EPUB file';
  static const String errorFileNotFound = 'File not found';
  static const String errorInvalidFormat = 'Invalid EPUB format';
  static const String errorMemory = 'Low memory. Please close other apps';
  static const String errorStorage = 'Insufficient storage space';
  static const String errorPermission = 'Storage permission required';

  // ==========================================================================
  // THEME COLORS
  // ==========================================================================
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color sepiaBackground = Color(0xFFF4ECD8);

  static const Color lightTextColor = Color(0xFF212121);
  static const Color darkTextColor = Color(0xFFE0E0E0);
  static const Color sepiaTextColor = Color(0xFF5B4636);
}

/// Download status enum
enum DownloadStatus {
  idle,
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Reading theme enum
enum ReadingTheme { light, dark, sepia }

/// Font family enum
enum ReaderFont {
  system('System Default'),
  serif('Serif'),
  sansSerif('Sans Serif'),
  monospace('Monospace');

  final String displayName;
  const ReaderFont(this.displayName);
}

/// Extension for DownloadStatus
extension DownloadStatusExtension on DownloadStatus {
  bool get isActive => this == DownloadStatus.downloading;
  bool get isPausable =>
      this == DownloadStatus.downloading || this == DownloadStatus.queued;
  bool get isResumable => this == DownloadStatus.paused;
  bool get isCancellable =>
      this == DownloadStatus.downloading ||
      this == DownloadStatus.paused ||
      this == DownloadStatus.queued;
  bool get isRetryable => this == DownloadStatus.failed;
  bool get isCompleted => this == DownloadStatus.completed;

  String get displayName {
    switch (this) {
      case DownloadStatus.idle:
        return 'Ready';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData get icon {
    switch (this) {
      case DownloadStatus.idle:
        return Icons.download_outlined;
      case DownloadStatus.queued:
        return Icons.queue;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline;
      case DownloadStatus.completed:
        return Icons.check_circle_outline;
      case DownloadStatus.failed:
        return Icons.error_outline;
      case DownloadStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DownloadStatus.idle:
        return Colors.grey;
      case DownloadStatus.queued:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.amber;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }
}

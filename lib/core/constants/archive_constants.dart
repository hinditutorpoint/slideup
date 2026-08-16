// lib/core/constants/app_constants.dart
class ArchiveConstants {
  ArchiveConstants._();

  // Archive.org API
  static const String archiveBaseUrl = 'https://archive.org';
  static const String advancedSearchPath = '/advancedsearch.php';
  static const String metadataPath = '/metadata';
  static const String downloadPath = '/download';

  // Default search parameters
  static const int defaultPageSize = 20;
  static const int requestTimeout = 30;

  // Media types
  static const String mediaTypePdf = 'texts';
  static const String mediaTypeAudio = 'audio';
  static const String mediaTypeVideo = 'movies';

  // Database
  static const String databaseName = 'slideup_archive_app.db';
  static const int databaseVersion = 3;

  // Table names
  static const String likedItemsTable = 'liked_items';
  static const String savedItemsTable = 'saved_items';

  // Shared Preferences keys
  static const String viewModeKey = 'view_mode';

  static const String downloadsTable = 'downloads';

  // Download
  static const String downloadFolder = 'ArchiveDownloads';
  static const int maxConcurrentDownloads = 3;

  // Notification channels
  static const String downloadChannelId = 'download_channel';
  static const String downloadChannelName = 'Downloads';
  static const String downloadChannelDesc = 'Download progress notifications';

  // WorkManager
  static const String downloadTaskName = 'archive_download_task';
}

class ApiFields {
  ApiFields._();

  static const List<String> searchFields = [
    'identifier',
    'title',
    'description',
    'creator',
    'date',
    'mediatype',
    'downloads',
    'item_size',
    'format',
    'language',
  ];
}

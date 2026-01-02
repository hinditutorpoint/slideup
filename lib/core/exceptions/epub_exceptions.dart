import 'package:flutter/material.dart';

/// Base exception for all EPUB related errors
abstract class EpubException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  EpubException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() =>
      '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';

  /// Get user-friendly message
  String get userMessage => message;

  /// Get icon for UI display
  IconData get icon => Icons.error_outline;

  /// Get severity level
  ExceptionSeverity get severity => ExceptionSeverity.error;

  /// Check if error is recoverable
  bool get isRecoverable => false;

  /// Get suggested action
  String? get suggestedAction => null;

  /// Convert to JSON for logging
  Map<String, dynamic> toJson() => {
    'type': runtimeType.toString(),
    'message': message,
    'code': code,
    'timestamp': timestamp.toIso8601String(),
    'originalError': originalError?.toString(),
    'stackTrace': stackTrace?.toString(),
  };
}

/// Exception severity levels
enum ExceptionSeverity { info, warning, error, critical }

// =============================================================================
// DOWNLOAD EXCEPTIONS
// =============================================================================

/// Exception for download related errors
class DownloadException extends EpubException {
  final String? url;
  final int? statusCode;
  final int? bytesDownloaded;
  final int? totalBytes;

  DownloadException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.url,
    this.statusCode,
    this.bytesDownloaded,
    this.totalBytes,
  });

  factory DownloadException.networkError({
    String? url,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return DownloadException(
      message: 'Network error occurred during download',
      code: 'NETWORK_ERROR',
      url: url,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory DownloadException.timeout({String? url, Duration? timeout}) {
    return DownloadException(
      message:
          'Download timed out${timeout != null ? ' after ${timeout.inSeconds}s' : ''}',
      code: 'DOWNLOAD_TIMEOUT',
      url: url,
    );
  }

  factory DownloadException.cancelled({String? url}) {
    return DownloadException(
      message: 'Download was cancelled',
      code: 'DOWNLOAD_CANCELLED',
      url: url,
    );
  }

  factory DownloadException.serverError({String? url, int? statusCode}) {
    return DownloadException(
      message:
          'Server returned error${statusCode != null ? ' ($statusCode)' : ''}',
      code: 'SERVER_ERROR',
      url: url,
      statusCode: statusCode,
    );
  }

  factory DownloadException.insufficientStorage({
    int? requiredBytes,
    int? availableBytes,
  }) {
    return DownloadException(
      message: 'Insufficient storage space',
      code: 'INSUFFICIENT_STORAGE',
      totalBytes: requiredBytes,
    );
  }

  @override
  IconData get icon => Icons.cloud_off;

  @override
  bool get isRecoverable => code != 'DOWNLOAD_CANCELLED';

  @override
  String? get suggestedAction {
    switch (code) {
      case 'NETWORK_ERROR':
        return 'Check your internet connection and try again';
      case 'DOWNLOAD_TIMEOUT':
        return 'Try downloading again';
      case 'SERVER_ERROR':
        return 'Try again later';
      case 'INSUFFICIENT_STORAGE':
        return 'Free up some storage space';
      default:
        return 'Try downloading again';
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'url': url,
    'statusCode': statusCode,
    'bytesDownloaded': bytesDownloaded,
    'totalBytes': totalBytes,
  };
}

// =============================================================================
// PARSING EXCEPTIONS
// =============================================================================

/// Exception for EPUB parsing errors
class EpubParseException extends EpubException {
  final String? filePath;
  final String? component;
  final int? lineNumber;

  EpubParseException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.filePath,
    this.component,
    this.lineNumber,
  });

  factory EpubParseException.invalidFormat({
    String? filePath,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return EpubParseException(
      message: 'Invalid EPUB format',
      code: 'INVALID_FORMAT',
      filePath: filePath,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory EpubParseException.corruptedFile({
    String? filePath,
    String? component,
  }) {
    return EpubParseException(
      message:
          'EPUB file is corrupted${component != null ? ' in $component' : ''}',
      code: 'CORRUPTED_FILE',
      filePath: filePath,
      component: component,
    );
  }

  factory EpubParseException.missingComponent({
    required String component,
    String? filePath,
  }) {
    return EpubParseException(
      message: 'Required component "$component" is missing',
      code: 'MISSING_COMPONENT',
      filePath: filePath,
      component: component,
    );
  }

  factory EpubParseException.invalidXml({
    String? filePath,
    String? component,
    int? lineNumber,
    dynamic originalError,
  }) {
    return EpubParseException(
      message: 'Invalid XML${lineNumber != null ? ' at line $lineNumber' : ''}',
      code: 'INVALID_XML',
      filePath: filePath,
      component: component,
      lineNumber: lineNumber,
      originalError: originalError,
    );
  }

  factory EpubParseException.unsupportedVersion({String? version}) {
    return EpubParseException(
      message:
          'Unsupported EPUB version${version != null ? ' ($version)' : ''}',
      code: 'UNSUPPORTED_VERSION',
    );
  }

  factory EpubParseException.encryptedContent() {
    return EpubParseException(
      message: 'EPUB content is encrypted and cannot be read',
      code: 'ENCRYPTED_CONTENT',
    );
  }

  @override
  IconData get icon => Icons.broken_image;

  @override
  String get userMessage => 'Failed to read EPUB file';

  @override
  String? get suggestedAction =>
      'Try downloading the file again or use a different EPUB file';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'filePath': filePath,
    'component': component,
    'lineNumber': lineNumber,
  };
}

// =============================================================================
// FILE EXCEPTIONS
// =============================================================================

/// Exception for file operations
class FileException extends EpubException {
  final String? path;
  final String? operation;

  FileException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.path,
    this.operation,
  });

  factory FileException.notFound({String? path}) {
    return FileException(
      message: 'File not found${path != null ? ': $path' : ''}',
      code: 'FILE_NOT_FOUND',
      path: path,
    );
  }

  factory FileException.permissionDenied({
    String? path,
    String? operation,
    dynamic originalError,
  }) {
    return FileException(
      message: 'Permission denied${operation != null ? ' for $operation' : ''}',
      code: 'PERMISSION_DENIED',
      path: path,
      operation: operation,
      originalError: originalError,
    );
  }

  factory FileException.readError({
    String? path,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return FileException(
      message: 'Failed to read file',
      code: 'READ_ERROR',
      path: path,
      operation: 'read',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory FileException.writeError({
    String? path,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return FileException(
      message: 'Failed to write file',
      code: 'WRITE_ERROR',
      path: path,
      operation: 'write',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory FileException.deleteError({String? path, dynamic originalError}) {
    return FileException(
      message: 'Failed to delete file',
      code: 'DELETE_ERROR',
      path: path,
      operation: 'delete',
      originalError: originalError,
    );
  }

  @override
  IconData get icon => Icons.folder_off;

  @override
  String? get suggestedAction {
    switch (code) {
      case 'FILE_NOT_FOUND':
        return 'Download the file again';
      case 'PERMISSION_DENIED':
        return 'Grant storage permission in settings';
      default:
        return 'Try the operation again';
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'path': path,
    'operation': operation,
  };
}

// =============================================================================
// CACHE EXCEPTIONS
// =============================================================================

/// Exception for cache operations
class CacheException extends EpubException {
  final String? cacheKey;
  final String? cacheType;

  CacheException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.cacheKey,
    this.cacheType,
  });

  factory CacheException.expired({String? cacheKey}) {
    return CacheException(
      message: 'Cache has expired',
      code: 'CACHE_EXPIRED',
      cacheKey: cacheKey,
    );
  }

  factory CacheException.notFound({String? cacheKey}) {
    return CacheException(
      message: 'Cache entry not found',
      code: 'CACHE_NOT_FOUND',
      cacheKey: cacheKey,
    );
  }

  factory CacheException.corrupted({String? cacheKey, String? cacheType}) {
    return CacheException(
      message: 'Cache data is corrupted',
      code: 'CACHE_CORRUPTED',
      cacheKey: cacheKey,
      cacheType: cacheType,
    );
  }

  factory CacheException.writeError({String? cacheKey, dynamic originalError}) {
    return CacheException(
      message: 'Failed to write to cache',
      code: 'CACHE_WRITE_ERROR',
      cacheKey: cacheKey,
      originalError: originalError,
    );
  }

  @override
  IconData get icon => Icons.cached;

  @override
  ExceptionSeverity get severity => ExceptionSeverity.warning;

  @override
  bool get isRecoverable => true;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'cacheKey': cacheKey,
    'cacheType': cacheType,
  };
}

// =============================================================================
// READER EXCEPTIONS
// =============================================================================

/// Exception for reader operations
class ReaderException extends EpubException {
  final String? bookId;
  final int? chapterIndex;
  final String? chapterId;

  ReaderException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.bookId,
    this.chapterIndex,
    this.chapterId,
  });

  factory ReaderException.chapterNotFound({
    String? bookId,
    int? chapterIndex,
    String? chapterId,
  }) {
    return ReaderException(
      message: 'Chapter not found',
      code: 'CHAPTER_NOT_FOUND',
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterId: chapterId,
    );
  }

  factory ReaderException.contentLoadError({
    String? bookId,
    int? chapterIndex,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return ReaderException(
      message: 'Failed to load chapter content',
      code: 'CONTENT_LOAD_ERROR',
      bookId: bookId,
      chapterIndex: chapterIndex,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory ReaderException.renderError({
    String? bookId,
    int? chapterIndex,
    dynamic originalError,
  }) {
    return ReaderException(
      message: 'Failed to render content',
      code: 'RENDER_ERROR',
      bookId: bookId,
      chapterIndex: chapterIndex,
      originalError: originalError,
    );
  }

  factory ReaderException.navigationError({
    String? bookId,
    int? targetChapter,
  }) {
    return ReaderException(
      message: 'Navigation failed',
      code: 'NAVIGATION_ERROR',
      bookId: bookId,
      chapterIndex: targetChapter,
    );
  }

  @override
  IconData get icon => Icons.menu_book_outlined;

  @override
  bool get isRecoverable => true;

  @override
  String? get suggestedAction => 'Try refreshing the content';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'bookId': bookId,
    'chapterIndex': chapterIndex,
    'chapterId': chapterId,
  };
}

// =============================================================================
// MEMORY EXCEPTIONS
// =============================================================================

/// Exception for memory related issues
class MemoryException extends EpubException {
  final int? currentUsageMB;
  final int? thresholdMB;

  MemoryException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.currentUsageMB,
    this.thresholdMB,
  });

  factory MemoryException.lowMemory({int? currentUsageMB, int? thresholdMB}) {
    return MemoryException(
      message: 'Low memory warning',
      code: 'LOW_MEMORY',
      currentUsageMB: currentUsageMB,
      thresholdMB: thresholdMB,
    );
  }

  factory MemoryException.outOfMemory({
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return MemoryException(
      message: 'Out of memory',
      code: 'OUT_OF_MEMORY',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  @override
  IconData get icon => Icons.memory;

  @override
  ExceptionSeverity get severity => ExceptionSeverity.critical;

  @override
  String get userMessage => 'App is running low on memory';

  @override
  String? get suggestedAction => 'Close other apps to free up memory';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'currentUsageMB': currentUsageMB,
    'thresholdMB': thresholdMB,
  };
}

// =============================================================================
// VALIDATION EXCEPTIONS
// =============================================================================

/// Exception for validation errors
class ValidationException extends EpubException {
  final String? field;
  final dynamic invalidValue;

  ValidationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.field,
    this.invalidValue,
  });

  factory ValidationException.invalidUrl({String? url}) {
    return ValidationException(
      message: 'Invalid URL format',
      code: 'INVALID_URL',
      field: 'url',
      invalidValue: url,
    );
  }

  factory ValidationException.emptyField({required String field}) {
    return ValidationException(
      message: '$field cannot be empty',
      code: 'EMPTY_FIELD',
      field: field,
    );
  }

  factory ValidationException.invalidRange({
    required String field,
    dynamic value,
    dynamic min,
    dynamic max,
  }) {
    return ValidationException(
      message: '$field must be between $min and $max',
      code: 'INVALID_RANGE',
      field: field,
      invalidValue: value,
    );
  }

  @override
  IconData get icon => Icons.warning_amber;

  @override
  ExceptionSeverity get severity => ExceptionSeverity.warning;

  @override
  bool get isRecoverable => true;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'field': field,
    'invalidValue': invalidValue?.toString(),
  };
}

// =============================================================================
// EXCEPTION HANDLER
// =============================================================================

/// Global exception handler
class ExceptionHandler {
  ExceptionHandler._();

  static final List<void Function(EpubException)> _listeners = [];

  /// Add exception listener
  static void addListener(void Function(EpubException) listener) {
    _listeners.add(listener);
  }

  /// Remove exception listener
  static void removeListener(void Function(EpubException) listener) {
    _listeners.remove(listener);
  }

  /// Handle exception
  static void handle(EpubException exception) {
    // Log exception
    _logException(exception);

    // Notify listeners
    for (final listener in _listeners) {
      try {
        listener(exception);
      } catch (_) {}
    }
  }

  /// Wrap any exception to EpubException
  static EpubException wrap(dynamic error, [StackTrace? stackTrace]) {
    if (error is EpubException) return error;

    final errorString = error.toString().toLowerCase();

    // Categorize common errors
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network')) {
      return DownloadException.networkError(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('timeout')) {
      return DownloadException.timeout();
    }

    if (errorString.contains('permission')) {
      return FileException.permissionDenied(originalError: error);
    }

    if (errorString.contains('file not found') ||
        errorString.contains('no such file')) {
      return FileException.notFound();
    }

    if (errorString.contains('memory')) {
      return MemoryException.outOfMemory(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Generic exception
    return _GenericEpubException(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static void _logException(EpubException exception) {
    debugPrint('''
╔══════════════════════════════════════════════════════════════════════════════
║ EPUB EXCEPTION
╠══════════════════════════════════════════════════════════════════════════════
║ Type: ${exception.runtimeType}
║ Code: ${exception.code}
║ Message: ${exception.message}
║ Severity: ${exception.severity.name}
║ Recoverable: ${exception.isRecoverable}
║ Timestamp: ${exception.timestamp}
║ Original Error: ${exception.originalError}
╚══════════════════════════════════════════════════════════════════════════════
''');
  }
}

/// Background service related exceptions
class BackgroundException extends EpubException {
  BackgroundException.workmanagerUnavailable()
    : super(
        message: 'Background services are not available on this device',
        code: 'WORKMANAGER_UNAVAILABLE',
      );

  BackgroundException.initializationFailed({String? details})
    : super(
        message: 'Failed to initialize background services: ${details ?? ''}',
        code: 'BACKGROUND_INIT_FAILED',
      );

  BackgroundException.taskSchedulingFailed({String? taskId, String? reason})
    : super(
        message:
            'Failed to schedule background task ${taskId ?? ''}: ${reason ?? ''}',
        code: 'TASK_SCHEDULING_FAILED',
      );

  @override
  IconData get icon => Icons.cloud_off;

  @override
  String? get suggestedAction =>
      'Some features may be limited without background services';

  @override
  bool get isRecoverable => false;
}

/// Generic exception for uncategorized errors
class _GenericEpubException extends EpubException {
  _GenericEpubException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'UNKNOWN_ERROR');

  @override
  String get userMessage => 'An unexpected error occurred';

  @override
  String? get suggestedAction => 'Please try again';
}

/// Extension for easy exception conversion
extension ExceptionConversion on dynamic {
  EpubException toEpubException([StackTrace? stackTrace]) {
    return ExceptionHandler.wrap(this, stackTrace);
  }
}

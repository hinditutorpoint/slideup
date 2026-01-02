abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({required this.message, this.code, this.originalError});

  @override
  String toString() => 'AppException: $message (Code: $code)';
}

class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network error occurred',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

class NoInternetException extends AppException {
  const NoInternetException({
    super.message = 'No internet connection',
    super.code = 'NO_INTERNET',
    super.originalError,
  });
}

class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    super.message = 'Server error occurred',
    super.code = 'SERVER_ERROR',
    this.statusCode,
    super.originalError,
  });
}

class ParseException extends AppException {
  const ParseException({
    super.message = 'Failed to parse response',
    super.code = 'PARSE_ERROR',
    super.originalError,
  });
}

class DatabaseException extends AppException {
  const DatabaseException({
    super.message = 'Database error occurred',
    super.code = 'DATABASE_ERROR',
    super.originalError,
  });
}

class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error occurred',
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

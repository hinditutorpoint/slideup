import 'dart:async';
import 'package:flutter/foundation.dart';

/// Result wrapper for safe async operations
class Result<T> {
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isSuccess;

  const Result._({
    this.data,
    this.error,
    this.stackTrace,
    required this.isSuccess,
  });

  factory Result.success(T data) => Result._(data: data, isSuccess: true);

  factory Result.failure(Object error, [StackTrace? stackTrace]) =>
      Result._(error: error, stackTrace: stackTrace, isSuccess: false);

  bool get isFailure => !isSuccess;

  T get requireData {
    if (isSuccess && data != null) return data as T;
    throw StateError('Cannot get data from failed result');
  }

  T getOrElse(T defaultValue) =>
      isSuccess ? (data ?? defaultValue) : defaultValue;

  T? getOrNull() => isSuccess ? data : null;

  Result<R> map<R>(R Function(T) transform) {
    if (isSuccess && data != null) {
      try {
        return Result.success(transform(data as T));
      } catch (e, st) {
        return Result.failure(e, st);
      }
    }
    return Result.failure(error ?? 'Unknown error', stackTrace);
  }

  Future<Result<R>> asyncMap<R>(Future<R> Function(T) transform) async {
    if (isSuccess && data != null) {
      try {
        return Result.success(await transform(data as T));
      } catch (e, st) {
        return Result.failure(e, st);
      }
    }
    return Result.failure(error ?? 'Unknown error', stackTrace);
  }

  void when({
    required void Function(T data) success,
    required void Function(Object error, StackTrace? stackTrace) failure,
  }) {
    if (isSuccess && data != null) {
      success(data as T);
    } else {
      failure(error ?? 'Unknown error', stackTrace);
    }
  }

  R fold<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    }
    return failure(error ?? 'Unknown error', stackTrace);
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'Result.success($data)';
    }
    return 'Result.failure($error)';
  }
}

/// Safe async utility class
class SafeAsync {
  SafeAsync._();

  /// Execute an async operation with comprehensive error handling
  static Future<Result<T>> run<T>(
    Future<T> Function() operation, {
    String? operationName,
    Duration? timeout,
    int retryCount = 0,
    Duration retryDelay = const Duration(seconds: 1),
    bool Function(Object error)? shouldRetry,
    void Function(Object error, int attempt)? onRetry,
  }) async {
    int attempts = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempts <= retryCount) {
      try {
        Future<T> future = operation();

        if (timeout != null) {
          future = future.timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'Operation ${operationName ?? 'unknown'} timed out',
              timeout,
            ),
          );
        }

        final result = await future;
        return Result.success(result);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        _logError(operationName, e, st, attempts);

        if (attempts < retryCount) {
          final canRetry = shouldRetry?.call(e) ?? _defaultShouldRetry(e);
          if (canRetry) {
            onRetry?.call(e, attempts + 1);
            await Future.delayed(retryDelay * (attempts + 1));
            attempts++;
            continue;
          }
        }
        break;
      }
    }

    return Result.failure(lastError ?? 'Unknown error', lastStackTrace);
  }

  /// Execute multiple async operations in parallel with error handling
  static Future<List<Result<T>>> runAll<T>(
    List<Future<T> Function()> operations, {
    bool stopOnFirstError = false,
  }) async {
    if (stopOnFirstError) {
      final results = <Result<T>>[];
      for (final operation in operations) {
        final result = await run(operation);
        results.add(result);
        if (result.isFailure) break;
      }
      return results;
    }

    return Future.wait(operations.map((op) => run(op)));
  }

  /// Execute async operations sequentially
  static Future<Result<List<T>>> runSequential<T>(
    List<Future<T> Function()> operations, {
    bool continueOnError = false,
  }) async {
    final results = <T>[];

    for (final operation in operations) {
      final result = await run(operation);
      if (result.isSuccess) {
        results.add(result.requireData);
      } else if (!continueOnError) {
        return Result.failure(result.error!, result.stackTrace);
      }
    }

    return Result.success(results);
  }

  /// Execute with automatic cancellation support
  static CancellableOperation<T> runCancellable<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) {
    return CancellableOperation<T>(operation, operationName: operationName);
  }

  /// Guard a stream with error handling
  static Stream<Result<T>> guardStream<T>(
    Stream<T> stream, {
    String? streamName,
  }) async* {
    try {
      await for (final value in stream) {
        yield Result.success(value);
      }
    } catch (e, st) {
      _logError(streamName, e, st, 0);
      yield Result.failure(e, st);
    }
  }

  /// Execute with debounce
  static Future<Result<T>> debounce<T>(
    Future<T> Function() operation, {
    required Duration duration,
    required String key,
  }) async {
    _debounceTimers[key]?.cancel();

    final completer = Completer<Result<T>>();
    _debounceTimers[key] = Timer(duration, () async {
      final result = await run(operation);
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    return completer.future;
  }

  static final Map<String, Timer> _debounceTimers = {};

  /// Execute with throttle
  static Future<Result<T>?> throttle<T>(
    Future<T> Function() operation, {
    required Duration duration,
    required String key,
  }) async {
    if (_throttleFlags[key] == true) {
      return null;
    }

    _throttleFlags[key] = true;
    Timer(duration, () => _throttleFlags[key] = false);

    return run(operation);
  }

  static final Map<String, bool> _throttleFlags = {};

  /// Cancel all debounce timers
  static void cancelAllDebounce() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Reset throttle flags
  static void resetThrottle() {
    _throttleFlags.clear();
  }

  static bool _defaultShouldRetry(Object error) {
    // Retry on network-related errors
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network');
  }

  static void _logError(
    String? operationName,
    Object error,
    StackTrace stackTrace,
    int attempt,
  ) {
    if (kDebugMode) {
      debugPrint('''
╔══════════════════════════════════════════════════════════════════════════════
║ SAFE ASYNC ERROR
║ Operation: ${operationName ?? 'Unknown'}
║ Attempt: ${attempt + 1}
║ Error: $error
║ Stack Trace: $stackTrace
╚══════════════════════════════════════════════════════════════════════════════
''');
    }
  }
}

/// Cancellable operation wrapper
class CancellableOperation<T> {
  final Future<T> Function() _operation;
  final String? operationName;

  bool _isCancelled = false;
  bool _isRunning = false;
  Completer<Result<T>>? _completer;

  CancellableOperation(this._operation, {this.operationName});

  bool get isCancelled => _isCancelled;

  Future<Result<T>> run() async {
    if (_isRunning) {
      return Result.failure(StateError('Operation already running'));
    }

    _isRunning = true;
    final completer = Completer<Result<T>>();
    _completer = completer;

    try {
      if (_isCancelled) {
        final cancelled = Result<T>.failure(CancelledException(operationName));
        if (!completer.isCompleted) {
          completer.complete(cancelled);
        }
        return cancelled;
      }

      final result = await _operation();

      if (_isCancelled) {
        final cancelled = Result<T>.failure(CancelledException(operationName));
        if (!completer.isCompleted) {
          completer.complete(cancelled);
        }
        return cancelled;
      }

      final success = Result.success(result);
      if (!completer.isCompleted) {
        completer.complete(success);
      }
      return success;
    } catch (e, st) {
      final failure = _isCancelled
          ? Result<T>.failure(CancelledException(operationName))
          : Result<T>.failure(e, st);

      if (!completer.isCompleted) {
        completer.complete(failure);
      }
      return failure;
    } finally {
      _isRunning = false;
    }
  }

  void cancel() {
    _isCancelled = true;

    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(Result.failure(CancelledException(operationName)));
    }
  }
}

/// Cancelled exception
class CancelledException implements Exception {
  final String? operationName;

  CancelledException([this.operationName]);

  @override
  String toString() =>
      'CancelledException: Operation ${operationName ?? 'unknown'} was cancelled';
}

/// Extension for Future with safe handling
extension SafeFutureExtension<T> on Future<T> {
  /// Convert Future to Result
  Future<Result<T>> toResult() async {
    try {
      return Result.success(await this);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Run with timeout and return Result
  Future<Result<T>> withTimeout(Duration timeout) async {
    try {
      return Result.success(await this.timeout(timeout));
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Handle errors gracefully
  Future<T?> orNull() async {
    try {
      return await this;
    } catch (_) {
      return null;
    }
  }

  /// Handle errors with default value
  Future<T> orDefault(T defaultValue) async {
    try {
      return await this;
    } catch (_) {
      return defaultValue;
    }
  }
}

/// Extension for Stream with safe handling
extension SafeStreamExtension<T> on Stream<T> {
  /// Convert Stream to Stream of Results
  Stream<Result<T>> toResultStream() {
    return SafeAsync.guardStream(this);
  }

  /// Handle errors gracefully in stream
  Stream<T?> orNull() async* {
    try {
      await for (final value in this) {
        yield value;
      }
    } catch (_) {
      yield null;
    }
  }
}

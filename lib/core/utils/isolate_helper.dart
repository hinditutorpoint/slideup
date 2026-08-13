import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'safe_async.dart';

/// Task priority for isolate execution
enum TaskPriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  final int value;
  const TaskPriority(this.value);
}

/// Isolate task wrapper
class IsolateTask<T, R> {
  final String id;
  final T data;
  final R Function(T) computation;
  final TaskPriority priority;
  final Completer<Result<R>> completer;
  final DateTime createdAt;

  IsolateTask({
    required this.id,
    required this.data,
    required this.computation,
    this.priority = TaskPriority.normal,
  }) : completer = Completer<Result<R>>(),
       createdAt = DateTime.now();

  bool get isCompleted => completer.isCompleted;
}

/// Message types for isolate communication
class IsolateMessage<T> {
  final String taskId;
  final String type; // 'result' or 'error'
  final T? data;
  final String? error;
  final StackTrace? stackTrace;

  IsolateMessage({
    required this.taskId,
    required this.type,
    this.data,
    this.error,
    this.stackTrace,
  });
}

/// Message sent into the worker isolate
class _IsolateTaskMessage<T, R> {
  final String taskId;
  final T data;
  final Function computation;
  R? result;

  _IsolateTaskMessage(this.taskId, this.data, this.computation);
}

/// Managed isolate wrapper
class ManagedIsolate {
  final String id;
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  bool _isBusy = false;
  bool _isDisposed = false;
  DateTime? _lastUsed;

  Completer<void>? _currentTaskCompleter;
  _IsolateTaskMessage<dynamic, dynamic>? _currentTask;
  Object? _currentError;
  StackTrace? _currentStackTrace;

  ManagedIsolate(this.id);

  bool get isAvailable => !_isBusy && !_isDisposed && _isolate != null;
  bool get isDisposed => _isDisposed;
  DateTime? get lastUsed => _lastUsed;

  Future<void> spawn() async {
    if (_isDisposed) return;

    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort!.sendPort);

    final initCompleter = Completer<void>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        initCompleter.complete();
      } else if (message is IsolateMessage) {
        _handleMessage(message);
      }
    });

    await initCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Isolate spawn timeout'),
    );
  }

  /// Entry point for the worker isolate
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is _IsolateTaskMessage) {
        try {
          final Function fn = message.computation;
          final result = fn(message.data);
          mainSendPort.send(
            IsolateMessage<dynamic>(
              taskId: message.taskId,
              type: 'result',
              data: result,
            ),
          );
        } catch (e, st) {
          mainSendPort.send(
            IsolateMessage<dynamic>(
              taskId: message.taskId,
              type: 'error',
              error: e.toString(),
              stackTrace: st,
            ),
          );
        }
      }
    });
  }

  /// Handle messages coming back from the worker isolate
  void _handleMessage(IsolateMessage<dynamic> message) {
    _isBusy = false;
    _lastUsed = DateTime.now();

    if (_currentTask != null && _currentTask!.taskId == message.taskId) {
      if (message.type == 'result') {
        // Store result into the current task
        _currentTask!.result = message.data;
        _currentError = null;
        _currentStackTrace = null;
      } else if (message.type == 'error') {
        _currentError = Exception(message.error ?? 'Isolate task error');
        _currentStackTrace = message.stackTrace;
        _currentTask!.result = null;
      }
    }

    _currentTaskCompleter?.complete();
    _currentTaskCompleter = null;
  }

  /// Execute one task in this managed isolate
  // ignore: library_private_types_in_public_api
  Future<Result<R>> execute<T, R>(_IsolateTaskMessage<T, R> task) async {
    if (_isDisposed || _sendPort == null) {
      return Result.failure(StateError('Isolate is not available'));
    }

    _isBusy = true;
    _lastUsed = DateTime.now();

    _currentTask = task as _IsolateTaskMessage<dynamic, dynamic>;
    _currentError = null;
    _currentStackTrace = null;
    _currentTaskCompleter = Completer<void>();

    try {
      _sendPort!.send(task);

      await _currentTaskCompleter!.future.timeout(
        AppConstants.isolateTimeout,
        onTimeout: () {
          // Mark as timeout failure
          _currentError = TimeoutException('Isolate task timeout');
          _currentTaskCompleter?.complete();
        },
      );

      // If isolate reported an error
      if (_currentError != null) {
        final err = _currentError!;
        final st = _currentStackTrace;
        return Result.failure(err, st);
      }

      // No error; we expect a non-null result
      if (task.result == null) {
        return Result.failure(
          StateError(
            'Isolate task "$id" returned null result for computation.',
          ),
        );
      }

      return Result.success(task.result as R);
    } catch (e, st) {
      _isBusy = false;
      return Result.failure(e, st);
    } finally {
      _currentTask = null;
      _currentError = null;
      _currentStackTrace = null;
      _currentTaskCompleter = null;
      _isBusy = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
    _currentTaskCompleter?.complete();
    _currentTaskCompleter = null;
    _currentTask = null;
    _currentError = null;
    _currentStackTrace = null;
  }
}

/// Isolate helper for running heavy tasks in background
class IsolateHelper {
  IsolateHelper._();

  static final IsolateHelper _instance = IsolateHelper._();
  static IsolateHelper get instance => _instance;

  final List<ManagedIsolate> _isolatePool = [];
  final Queue<IsolateTask> _taskQueue = Queue();
  Timer? _cleanupTimer;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  int get poolSize => _isolatePool.length;
  int get queuedTasks => _taskQueue.length;

  /// Initialize isolate pool
  Future<void> initialize({int poolSize = 2}) async {
    if (_isInitialized) return;

    try {
      final effectivePoolSize = poolSize.clamp(
        1,
        AppConstants.maxIsolatePoolSize,
      );

      for (int i = 0; i < effectivePoolSize; i++) {
        final isolate = ManagedIsolate('isolate_$i');
        await isolate.spawn();
        _isolatePool.add(isolate);
      }

      _startCleanupTimer();
      _isInitialized = true;
      debugPrint('IsolateHelper initialized with $effectivePoolSize isolates');
    } catch (e) {
      debugPrint('IsolateHelper initialization error: $e');
    }
  }

  /// Start cleanup timer for idle isolates
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      AppConstants.isolateKeepAlive,
      (_) => _cleanupIdleIsolates(),
    );
  }

  /// Clean up idle isolates
  void _cleanupIdleIsolates() {
    if (_isolatePool.length <= 1) return;

    final now = DateTime.now();
    _isolatePool.removeWhere((isolate) {
      if (isolate.isAvailable &&
          isolate.lastUsed != null &&
          now.difference(isolate.lastUsed!) > AppConstants.isolateKeepAlive) {
        isolate.dispose();
        return true;
      }
      return false;
    });
  }

  /// Run computation in isolate
  Future<Result<R>> compute<T, R>(
    R Function(T) computation,
    T data, {
    String? taskId,
    TaskPriority priority = TaskPriority.normal,
  }) async {
    // Use Flutter's compute for simple cases or when pool is not ready
    if (!_isInitialized || _isolatePool.isEmpty) {
      try {
        return await flutterCompute<T, R>(computation, data);
      } catch (e, st) {
        return Result.failure(e, st);
      }
    }

    final task = IsolateTask<T, R>(
      id: taskId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
      computation: computation,
      priority: priority,
    );

    return _executeTask(task);
  }

  /// Use Flutter's compute function
  static Future<Result<R>> flutterCompute<T, R>(
    R Function(T) callback,
    T message, {
    String? operationName,
  }) async {
    try {
      final R result = await foundation.compute<T, R>(callback, message);
      return Result<R>.success(result);
    } catch (e, st) {
      return Result<R>.failure(e, st);
    }
  }

  /// Execute task in available isolate
  Future<Result<R>> _executeTask<T, R>(IsolateTask<T, R> task) async {
    // Find available isolate
    ManagedIsolate? isolate = _isolatePool.cast<ManagedIsolate?>().firstWhere(
      (i) => i!.isAvailable,
      orElse: () => null,
    );

    if (isolate == null) {
      // All isolates busy; queue the task or create a new isolate
      if (_isolatePool.length < AppConstants.maxIsolatePoolSize) {
        isolate = ManagedIsolate('isolate_${_isolatePool.length}');
        await isolate.spawn();
        _isolatePool.add(isolate);
      } else {
        // Queue the task
        _taskQueue.add(task);
        return task.completer.future;
      }
    }

    try {
      final result = await isolate.execute(
        _IsolateTaskMessage<T, R>(task.id, task.data, task.computation),
      );

      if (!task.completer.isCompleted) {
        task.completer.complete(result);
      }

      _processQueue();

      return result;
    } catch (e, st) {
      final errorResult = Result<R>.failure(e, st);
      if (!task.completer.isCompleted) {
        task.completer.complete(errorResult);
      }
      return errorResult;
    }
  }

  /// Process queued tasks
  void _processQueue() {
    if (_taskQueue.isEmpty) return;

    final availableIsolate = _isolatePool.cast<ManagedIsolate?>().firstWhere(
      (i) => i!.isAvailable,
      orElse: () => null,
    );

    if (availableIsolate != null && _taskQueue.isNotEmpty) {
      // Sort by priority (higher priority first)
      final sortedTasks = _taskQueue.toList()
        ..sort((a, b) => b.priority.value.compareTo(a.priority.value));
      _taskQueue.clear();
      _taskQueue.addAll(sortedTasks);

      final task = _taskQueue.removeFirst();
      _executeTask(task);
    }
  }

  /// Run multiple computations in parallel
  Future<List<Result<R>>> computeAll<T, R>(
    R Function(T) computation,
    List<T> dataList, {
    TaskPriority priority = TaskPriority.normal,
  }) async {
    final futures = dataList.map(
      (data) => compute(computation, data, priority: priority),
    );

    return Future.wait(futures);
  }

  /// Run computation with timeout
  Future<Result<R>> computeWithTimeout<T, R>(
    R Function(T) computation,
    T data,
    Duration timeout, {
    TaskPriority priority = TaskPriority.normal,
  }) async {
    try {
      final result = await compute(
        computation,
        data,
        priority: priority,
      ).timeout(timeout);
      return result;
    } on TimeoutException {
      return Result.failure(TimeoutException('Computation timed out', timeout));
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Cancel all pending tasks
  void cancelAllTasks() {
    for (final task in _taskQueue) {
      if (!task.completer.isCompleted) {
        task.completer.complete(
          Result.failure(CancelledException('Task cancelled')),
        );
      }
    }
    _taskQueue.clear();
  }

  /// Dispose all isolates
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    cancelAllTasks();

    for (final isolate in _isolatePool) {
      isolate.dispose();
    }
    _isolatePool.clear();

    _isInitialized = false;
    debugPrint('IsolateHelper disposed');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'poolSize': _isolatePool.length,
      'availableIsolates': _isolatePool.where((i) => i.isAvailable).length,
      'queuedTasks': _taskQueue.length,
    };
  }
}

/// Additional isolate-safe helpers (unchanged)
class IsolateCompute {
  IsolateCompute._();

  static Future<Result<Map<String, dynamic>>> parseJson(String jsonString) {
    return IsolateHelper.instance.compute((String json) {
      return Map<String, dynamic>.from(
        (const JsonDecoder().convert(json)) as Map,
      );
    }, jsonString);
  }

  static Future<Result<String>> encodeJson(Map<String, dynamic> data) {
    return IsolateHelper.instance.compute((Map<String, dynamic> input) {
      return const JsonEncoder().convert(input);
    }, data);
  }

  static Future<Result<List<R>>> mapList<T, R>(
    List<T> list,
    R Function(T) mapper,
  ) {
    return IsolateHelper.instance.compute(
      (List<T> items) => items.map(mapper).toList(),
      list,
    );
  }

  static Future<Result<List<T>>> filterList<T>(
    List<T> list,
    bool Function(T) predicate,
  ) {
    return IsolateHelper.instance.compute(
      (List<T> items) => items.where(predicate).toList(),
      list,
    );
  }

  static Future<Result<List<T>>> sortList<T>(
    List<T> list,
    int Function(T, T) compare,
  ) {
    return IsolateHelper.instance.compute(
      (List<T> items) => items..sort(compare),
      List<T>.from(list),
    );
  }

  static Future<Result<List<int>>> searchText(
    String text,
    String query, {
    bool caseSensitive = false,
  }) {
    return IsolateHelper.instance.compute((_SearchParams params) {
      final positions = <int>[];
      final searchText = params.caseSensitive
          ? params.text
          : params.text.toLowerCase();
      final searchQuery = params.caseSensitive
          ? params.query
          : params.query.toLowerCase();

      int index = 0;
      while (true) {
        index = searchText.indexOf(searchQuery, index);
        if (index == -1) break;
        positions.add(index);
        index += searchQuery.length;
      }

      return positions;
    }, _SearchParams(text, query, caseSensitive));
  }
}

class _SearchParams {
  final String text;
  final String query;
  final bool caseSensitive;

  _SearchParams(this.text, this.query, this.caseSensitive);
}

class JsonDecoder {
  const JsonDecoder();

  dynamic convert(String input) {
    return _parseValue(input.trim(), 0).$1;
  }

  (dynamic, int) _parseValue(String input, int index) {
    if (index >= input.length) return (null, index);

    final char = input[index];

    if (char == '{') return _parseObject(input, index);
    if (char == '[') return _parseArray(input, index);
    if (char == '"') return _parseString(input, index);
    if (char == 't' || char == 'f') return _parseBool(input, index);
    if (char == 'n') return _parseNull(input, index);
    if (char == '-' || (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
      return _parseNumber(input, index);
    }

    return (null, index);
  }

  (Map<String, dynamic>, int) _parseObject(String input, int index) {
    final map = <String, dynamic>{};
    index++; // Skip '{'

    while (index < input.length) {
      index = _skipWhitespace(input, index);
      if (input[index] == '}') return (map, index + 1);

      if (input[index] == ',') {
        index++;
        continue;
      }

      final (key, nextIndex) = _parseString(input, index);
      index = _skipWhitespace(input, nextIndex);
      index++; // Skip ':'
      index = _skipWhitespace(input, index);

      final (value, valueIndex) = _parseValue(input, index);
      map[key] = value;
      index = _skipWhitespace(input, valueIndex);
    }

    return (map, index);
  }

  (List<dynamic>, int) _parseArray(String input, int index) {
    final list = <dynamic>[];
    index++; // Skip '['

    while (index < input.length) {
      index = _skipWhitespace(input, index);
      if (input[index] == ']') return (list, index + 1);

      if (input[index] == ',') {
        index++;
        continue;
      }

      final (value, nextIndex) = _parseValue(input, index);
      list.add(value);
      index = _skipWhitespace(input, nextIndex);
    }

    return (list, index);
  }

  (String, int) _parseString(String input, int index) {
    index++; // Skip opening quote
    final buffer = StringBuffer();

    while (index < input.length && input[index] != '"') {
      if (input[index] == '\\' && index + 1 < input.length) {
        index++;
        switch (input[index]) {
          case 'n':
            buffer.write('\n');
            break;
          case 't':
            buffer.write('\t');
            break;
          case 'r':
            buffer.write('\r');
            break;
          default:
            buffer.write(input[index]);
        }
      } else {
        buffer.write(input[index]);
      }
      index++;
    }

    return (buffer.toString(), index + 1); // Skip closing quote
  }

  (num, int) _parseNumber(String input, int index) {
    final start = index;
    if (input[index] == '-') index++;

    while (index < input.length &&
        (input[index].codeUnitAt(0) >= 48 && input[index].codeUnitAt(0) <= 57 ||
            input[index] == '.' ||
            input[index] == 'e' ||
            input[index] == 'E' ||
            input[index] == '+' ||
            input[index] == '-')) {
      index++;
    }

    final numStr = input.substring(start, index);
    return (num.parse(numStr), index);
  }

  (bool, int) _parseBool(String input, int index) {
    if (input.substring(index).startsWith('true')) {
      return (true, index + 4);
    }
    return (false, index + 5);
  }

  (dynamic, int) _parseNull(String input, int index) {
    return (null, index + 4);
  }

  int _skipWhitespace(String input, int index) {
    while (index < input.length &&
        (input[index] == ' ' ||
            input[index] == '\n' ||
            input[index] == '\r' ||
            input[index] == '\t')) {
      index++;
    }
    return index;
  }
}

class JsonEncoder {
  const JsonEncoder();

  String convert(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is String) return _encodeString(value);
    if (value is List) return _encodeList(value);
    if (value is Map) return _encodeMap(value);
    return 'null';
  }

  String _encodeString(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}"';
  }

  String _encodeList(List<dynamic> list) {
    return '[${list.map(convert).join(',')}]';
  }

  String _encodeMap(Map<dynamic, dynamic> map) {
    final entries = map.entries.map(
      (e) => '${_encodeString(e.key.toString())}:${convert(e.value)}',
    );
    return '{${entries.join(',')}}';
  }
}

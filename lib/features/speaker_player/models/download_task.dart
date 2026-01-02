import 'dart:async';
import 'package:dio/dio.dart';

class DownloadTask {
  final String modelId;
  final String tempFilePath;

  int downloadedBytes;
  bool isPaused = false;
  bool isCancelled = false;

  CancelToken _cancelToken = CancelToken();
  CancelToken get cancelToken => _cancelToken;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  DownloadTask({
    required this.modelId,
    required this.tempFilePath,
    this.downloadedBytes = 0,
  });

  void pause() {
    isPaused = true;
  }

  void resume() {
    isPaused = false;
    isCancelled = false;
  }

  /// Reset cancel token for resume after pause
  void resetCancelToken() {
    if (_cancelToken.isCancelled) {
      _cancelToken = CancelToken();
    }
    isCancelled = false;
    isPaused = false;
  }

  void updateProgress(double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void dispose() {
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}

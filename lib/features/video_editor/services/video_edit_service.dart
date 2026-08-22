// STUB — P1: legacy service replaced by reel_editor P7 export engine.
import 'package:flutter/foundation.dart';
import '../../../core/utils/safe_async.dart';
import '../models/video_edit_settings.dart';
import 'thumbnail_service.dart';

class VideoInfo {
  final Duration duration; final int width; final int height; final double fps;
  const VideoInfo({required this.duration, this.width=1920, this.height=1080, this.fps=30});
  String get resolution => '${width}x$height';
}

class VideoEditService {
  Future<Result<void>> initialize() async => Result.success(null);
  Future<Result<VideoInfo>> getVideoInfo(String path) async {
    try {
      final info = await ThumbnailService().getVideoInfo(path);
      final duration = (info?['duration'] as Duration?) ??
          const Duration(seconds: 10);
      final width = (info?['width'] as int?) ?? 1920;
      final height = (info?['height'] as int?) ?? 1080;
      final fps = (info?['fps'] as double?) ?? 30.0;
      return Result.success(
        VideoInfo(
          duration: duration,
          width: width,
          height: height,
          fps: fps,
        ),
      );
    } catch (e) {
      debugPrint('❌ getVideoInfo error: $e');
      return Result.success(const VideoInfo(duration: Duration(seconds: 10)));
    }
  }
  Future<Result<List<Uint8List>>> extractFrames({required String inputPath, int fps=1, int maxFrames=20, int width=160, int height=90}) async {
    try {
      final info = await ThumbnailService().getVideoInfo(inputPath);
      final duration = (info?['duration'] as Duration?) ?? Duration.zero;
      final thumbnails = await ThumbnailService().generateTimelineThumbnails(
        videoPath: inputPath,
        videoDuration: duration,
        count: maxFrames,
        width: width,
        height: height,
      );
      return Result.success(thumbnails);
    } catch (e) {
      debugPrint('❌ extractFrames error: $e');
      return Result.success(<Uint8List>[]);
    }
  }
  Future<Result<String>> mergeVideos({required List<MergeItem> items, void Function(double)? onProgress}) async => Result.success('');
  Future<Result<String>> extractAudio({required String inputPath, required AudioFormat format, int bitrate=192}) async => Result.success('');
  void dispose() {}
}

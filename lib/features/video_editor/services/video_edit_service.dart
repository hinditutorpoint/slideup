// STUB — P1: legacy service replaced by reel_editor P7 export engine.
import 'dart:typed_data';
import '../../../core/utils/safe_async.dart';
import '../models/video_edit_settings.dart';

class VideoInfo {
  final Duration duration; final int width; final int height; final double fps;
  const VideoInfo({required this.duration, this.width=1920, this.height=1080, this.fps=30});
  String get resolution => '${width}x$height';
}

class VideoEditService {
  Future<Result<void>> initialize() async => Result.success(null);
  Future<Result<VideoInfo>> getVideoInfo(String path) async => Result.success(VideoInfo(duration: const Duration(seconds: 10)));
  Future<Result<List<Uint8List>>> extractFrames({required String inputPath, int fps=1, int maxFrames=20, int width=160, int height=90}) async => Result.success([]);
  Future<Result<String>> mergeVideos({required List<MergeItem> items, void Function(double)? onProgress}) async => Result.success('');
  Future<Result<String>> extractAudio({required String inputPath, required AudioFormat format, int bitrate=192}) async => Result.success('');
  void dispose() {}
}

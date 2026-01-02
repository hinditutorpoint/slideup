import 'dart:io';
import 'dart:convert';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:flutter/foundation.dart';

enum CaptureFormat { png, jpg, bmp, webp }

enum VideoRotation { rotate90, rotate180, rotate270 }

enum VideoFlip { horizontal, vertical }

class VideoService {
  static final VideoService instance = VideoService._init();
  VideoService._init();

  // Get app files directory
  Future<Directory> _getAppFilesDirectory() async {
    final appDir = await getExternalStorageDirectory();
    final filesDir = Directory(appDir!.path);

    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    return filesDir;
  }

  // Get screenshots subdirectory
  Future<Directory> _getScreenshotsDirectory() async {
    final filesDir = await _getAppFilesDirectory();
    final screenshotsDir = Directory('${filesDir.path}/screenshots');

    if (!await screenshotsDir.exists()) {
      await screenshotsDir.create(recursive: true);
    }

    return screenshotsDir;
  }

  // Get audio subdirectory
  Future<Directory> _getAudioDirectory() async {
    final filesDir = await _getAppFilesDirectory();
    final audioDir = Directory('${filesDir.path}/audio');

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  // Get frames subdirectory
  Future<Directory> _getFramesDirectory() async {
    final filesDir = await _getAppFilesDirectory();
    final framesDir = Directory('${filesDir.path}/frames');

    if (!await framesDir.exists()) {
      await framesDir.create(recursive: true);
    }

    return framesDir;
  }

  // Capture screenshot from video at current position
  Future<String?> captureScreenshot({
    required String videoPath,
    required int timeInMilliseconds,
    CaptureFormat format = CaptureFormat.png,
    bool saveToGallery = true,
  }) async {
    try {
      final screenshotsDir = await _getScreenshotsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format.name;
      final outputPath =
          '${screenshotsDir.path}/screenshot_$timestamp.$extension';

      final timeInSeconds = timeInMilliseconds / 1000;

      final command =
          '-ss $timeInSeconds -i "$videoPath" -vframes 1 -q:v 2 "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (saveToGallery) {
          await SaverGallery.saveFile(
            filePath: outputPath,
            fileName: path.basename(outputPath),
            androidRelativePath: 'Screenshots/Slideup',
            skipIfExists: false,
          );
        }
        return outputPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      return null;
    }
  }

  // Record video segment
  Future<String?> recordScene({
    required String videoPath,
    required int startTimeMs,
    required int endTimeMs,
    String? outputPath,
  }) async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final output =
          outputPath ?? '${outputDir.path}/recorded_scene_$timestamp.mp4';

      final startTime = startTimeMs / 1000;
      final duration = (endTimeMs - startTimeMs) / 1000;

      final command =
          '-ss $startTime -i "$videoPath" -t $duration -c copy "$output"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return output;
      }

      return null;
    } catch (e) {
      debugPrint('Error recording scene: $e');
      return null;
    }
  }

  // Extract audio from video
  Future<String?> extractAudio({
    required String videoPath,
    String audioFormat = 'mp3',
    int? bitrate, // kbps
  }) async {
    try {
      final audioDir = await _getAudioDirectory();
      final videoName = path.basenameWithoutExtension(videoPath);

      final outputPath = '${audioDir.path}/${videoName}_audio.$audioFormat';

      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        return outputPath;
      }

      String command = '-y -i "$videoPath" -vn -acodec';

      switch (audioFormat.toLowerCase()) {
        case 'mp3':
          command += ' libmp3lame';
          break;
        case 'aac':
          command += ' aac';
          break;
        case 'wav':
          command += ' pcm_s16le';
          break;
        case 'flac':
          command += ' flac';
          break;
        default:
          command += ' copy';
      }

      if (bitrate != null) {
        command += ' -b:a ${bitrate}k';
      }

      command += ' "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting audio: $e');
      return null;
    }
  }

  // Extract frames/images from video
  Future<List<String>?> extractFrames({
    required String videoPath,
    int? startTimeMs,
    int? endTimeMs,
    int fps = 1, // frames per second to extract
    CaptureFormat format = CaptureFormat.jpg,
  }) async {
    try {
      final framesBaseDir = await _getFramesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final framesDir = Directory('${framesBaseDir.path}/frames_$timestamp');

      if (!await framesDir.exists()) {
        await framesDir.create(recursive: true);
      }

      final outputPattern = '${framesDir.path}/frame_%04d.${format.name}';

      String command = '';

      if (startTimeMs != null) {
        command += '-ss ${startTimeMs / 1000} ';
      }

      command += '-i "$videoPath" ';

      if (endTimeMs != null && startTimeMs != null) {
        final duration = (endTimeMs - startTimeMs) / 1000;
        command += '-t $duration ';
      }

      command += '-vf fps=$fps "$outputPattern"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final files = await framesDir.list().where((e) => e is File).toList();
        return files.map((e) => e.path).toList();
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting frames: $e');
      return null;
    }
  }

  // Rotate video
  Future<String?> rotateVideo({
    required String videoPath,
    required VideoRotation rotation,
  }) async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(videoPath);
      final outputPath = '${outputDir.path}/rotated_$timestamp$extension';

      String transposeValue;
      switch (rotation) {
        case VideoRotation.rotate90:
          transposeValue = '1'; // 90 degrees clockwise
          break;
        case VideoRotation.rotate180:
          transposeValue = '2,transpose=2'; // 180 degrees
          break;
        case VideoRotation.rotate270:
          transposeValue = '2'; // 90 degrees counter-clockwise
          break;
      }

      final command =
          '-i "$videoPath" -vf "transpose=$transposeValue" -c:a copy "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error rotating video: $e');
      return null;
    }
  }

  // Flip video
  Future<String?> flipVideo({
    required String videoPath,
    required VideoFlip flip,
  }) async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(videoPath);
      final outputPath = '${outputDir.path}/flipped_$timestamp$extension';

      final flipFilter = flip == VideoFlip.horizontal ? 'hflip' : 'vflip';
      final command =
          '-i "$videoPath" -vf "$flipFilter" -c:a copy "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error flipping video: $e');
      return null;
    }
  }

  // Convert video format (useful for HLS, MPD support)
  Future<String?> convertVideo({
    required String inputPath,
    required String outputFormat,
    String? codec,
    int? bitrate,
  }) async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/converted_$timestamp.$outputFormat';

      String command = '-i "$inputPath"';

      if (codec != null) {
        command += ' -c:v $codec';
      }

      if (bitrate != null) {
        command += ' -b:v ${bitrate}k';
      }

      command += ' "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error converting video: $e');
      return null;
    }
  }

  // Get video information
  Future<Map<String, dynamic>?> getVideoInfo(String videoPath) async {
    try {
      final session = await FFmpegKit.execute('-i "$videoPath" -hide_banner');

      final output = await session.getOutput();

      // Parse ffmpeg output for video information
      // This is a simplified version
      return {'path': videoPath, 'output': output};
    } catch (e) {
      debugPrint('Error getting video info: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getMediaMetadata(String path) async {
    final session = await FFmpegKit.execute(
      '-v quiet -print_format json -show_format -show_streams "$path"',
    );

    final output = await session.getOutput();

    if (output == null) return {};

    return jsonDecode(output);
  }

  // Cancel ongoing operation
  Future<void> cancelAllSessions() async {
    await FFmpegKit.cancel();
  }
}

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/audio_track.dart';

class AudioTrackService {
  // ✅ Get available audio tracks using FFprobe
  static Future<List<AudioTrack>> getAvailableAudioTracks(
    String videoPath,
  ) async {
    try {
      debugPrint('🔍 Analyzing audio tracks for: $videoPath');

      final session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        debugPrint('❌ No media information found');
        return [];
      }

      final streams = mediaInformation.getStreams();
      final audioTracks = <AudioTrack>[];

      int audioIndex = 0;

      for (final stream in streams) {
        if (stream.getType() == 'audio') {
          final track = _parseAudioTrack(stream, audioIndex);
          if (track != null) {
            audioTracks.add(track);
            audioIndex++;
          }
        }
      }

      debugPrint('✅ Found ${audioTracks.length} audio tracks');
      for (final track in audioTracks) {
        debugPrint('  - Track ${track.id}: ${track.label} (${track.language})');
      }

      return audioTracks;
    } catch (e) {
      debugPrint('❌ Error analyzing audio tracks: $e');
      return [];
    }
  }

  // ✅ Fixed: Parse audio track from FFprobe stream information
  static AudioTrack? _parseAudioTrack(StreamInformation stream, int index) {
    try {
      // ✅ Get properties as Map<Object?, Object?>
      final properties = stream.getAllProperties();

      // ✅ Safe helper function to get string values
      String? getStringValue(Map<Object?, Object?>? map, String key) {
        if (map == null) return null;
        final value = map[key];
        return value?.toString();
      }

      // ✅ Safe helper function to get int values
      int? getIntValue(Map<Object?, Object?>? map, String key) {
        if (map == null) return null;
        final value = map[key];
        if (value == null) return null;

        try {
          if (value is int) return value;
          if (value is String) return int.tryParse(value);
          return int.tryParse(value.toString());
        } catch (e) {
          return null;
        }
      }

      // ✅ Safe helper function to get nested map
      Map<Object?, Object?>? getNestedMap(
        Map<Object?, Object?>? map,
        String key,
      ) {
        if (map == null) return null;
        final value = map[key];
        if (value is Map<Object?, Object?>) return value;
        return null;
      }

      // Extract language from tags
      String language = 'Unknown';
      final tags = getNestedMap(properties, 'tags');
      if (tags != null) {
        language =
            getStringValue(tags, 'language') ??
            getStringValue(tags, 'LANGUAGE') ??
            'Unknown';
      }

      // Extract codec
      final codec =
          getStringValue(properties, 'codec_name')?.toUpperCase() ?? 'Unknown';

      // Extract channels
      final channels = getIntValue(properties, 'channels') ?? 2;

      // Extract bitrate
      final bitrate = getIntValue(properties, 'bit_rate');

      // Extract title/label from tags
      String label = 'Track $index';
      if (tags != null) {
        label =
            getStringValue(tags, 'title') ??
            getStringValue(tags, 'TITLE') ??
            'Track $index';
      }

      // Check if default from disposition
      bool isDefault = false;
      final disposition = getNestedMap(properties, 'disposition');
      if (disposition != null) {
        final defaultValue = disposition['default'];
        isDefault =
            defaultValue == 1 || defaultValue == '1' || defaultValue == true;
      }

      return AudioTrack(
        id: index,
        language: _getLanguageName(language),
        label: '$label ($codec)',
        channels: channels,
        codec: codec,
        bitrate: bitrate,
        isDefault: isDefault,
      );
    } catch (e) {
      debugPrint('❌ Error parsing audio track $index: $e');
      return null;
    }
  }

  // ✅ Convert language codes to readable names
  static String _getLanguageName(String langCode) {
    final languageMap = {
      'eng': 'English',
      'en': 'English',
      'spa': 'Spanish',
      'es': 'Spanish',
      'fre': 'French',
      'fr': 'French',
      'ger': 'German',
      'de': 'German',
      'ita': 'Italian',
      'it': 'Italian',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'rus': 'Russian',
      'ru': 'Russian',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zh': 'Chinese',
      'ara': 'Arabic',
      'ar': 'Arabic',
      'hin': 'Hindi',
      'hi': 'Hindi',
      'und': 'Unknown',
    };

    return languageMap[langCode.toLowerCase()] ?? langCode.toUpperCase();
  }

  // ✅ Extract specific audio track to temp file for switching
  static Future<String?> extractAudioTrack(
    String videoPath,
    int trackIndex,
  ) async {
    try {
      final tempPath = await _getTempAudioPath(videoPath, trackIndex);

      final command =
          '-i "$videoPath" -map 0:a:$trackIndex -c copy "$tempPath"';

      debugPrint('🔄 Extracting audio track $trackIndex...');
      debugPrint('Command: ffmpeg $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Audio track extracted to: $tempPath');
        return tempPath;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ Failed to extract audio track: $logs');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error extracting audio track: $e');
      return null;
    }
  }

  // ✅ Create video with specific audio track
  static Future<String?> createVideoWithAudioTrack(
    String videoPath,
    int audioTrackIndex,
  ) async {
    try {
      final outputPath = await _getTempVideoPath(videoPath, audioTrackIndex);

      // Copy video stream and specific audio track
      final command =
          '-i "$videoPath" -map 0:v:0 -map 0:a:$audioTrackIndex -c copy "$outputPath"';

      debugPrint('🔄 Creating video with audio track $audioTrackIndex...');
      debugPrint('Command: ffmpeg $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Video with audio track created: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ Failed to create video with audio track: $logs');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating video with audio track: $e');
      return null;
    }
  }

  // ✅ Get video info with all streams - Fixed type casting
  static Future<Map<String, dynamic>?> getVideoInfo(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) return null;

      final streams = mediaInfo.getStreams();
      final videoStreams = <Map<String, dynamic>>[];
      final audioStreams = <Map<String, dynamic>>[];

      for (final stream in streams) {
        // ✅ Convert properties safely
        final rawProperties = stream.getAllProperties();
        final properties = <String, dynamic>{};

        if (rawProperties != null) {
          rawProperties.forEach((key, value) {
            if (key != null) {
              properties[key.toString()] = value;
            }
          });
        }

        final streamInfo = {
          'index': stream.getIndex(),
          'type': stream.getType(),
          'codec': stream.getCodec(),
          'properties': properties,
        };

        if (stream.getType() == 'video') {
          videoStreams.add(streamInfo);
        } else if (stream.getType() == 'audio') {
          audioStreams.add(streamInfo);
        }
      }

      return {
        'duration': mediaInfo.getDuration(),
        'size': mediaInfo.getSize(),
        'format': mediaInfo.getFormat(),
        'videoStreams': videoStreams,
        'audioStreams': audioStreams,
      };
    } catch (e) {
      debugPrint('❌ Error getting video info: $e');
      return null;
    }
  }

  // ✅ Helper methods for temp file paths
  static Future<String> _getTempAudioPath(
    String videoPath,
    int trackIndex,
  ) async {
    final fileName = videoPath.split('/').last.split('.').first;
    final tempDir =
        '/data/data/com.slideup.mediaplayer/cache'; // Android cache dir
    return '$tempDir/${fileName}_audio_$trackIndex.aac';
  }

  static Future<String> _getTempVideoPath(
    String videoPath,
    int audioTrackIndex,
  ) async {
    final fileName = videoPath.split('/').last.split('.').first;
    final extension = videoPath.split('.').last;
    final tempDir = '/data/data/com.slideup.mediaplayer/cache';
    return '$tempDir/${fileName}_track_$audioTrackIndex.$extension';
  }

  // ✅ Clean up temporary files
  static Future<void> cleanupTempFiles() async {
    try {
      final command =
          'find /data/data/com.slideup.mediaplayer/cache -name "*_track_*" -delete';
      await FFmpegKit.execute(command);
      debugPrint('🧹 Cleaned up temporary audio track files');
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }

  // ✅ Alternative method using FFprobe JSON output (more reliable)
  static Future<List<AudioTrack>> getAvailableAudioTracksViaJson(
    String videoPath,
  ) async {
    try {
      debugPrint('🔍 Analyzing audio tracks via JSON for: $videoPath');

      final command = '-v quiet -print_format json -show_streams "$videoPath"';

      final session = await FFprobeKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        debugPrint('❌ FFprobe command failed');
        return [];
      }

      final output = await session.getOutput();
      if (output == null || output.isEmpty) {
        debugPrint('❌ No FFprobe output');
        return [];
      }

      try {
        final jsonData = jsonDecode(output);
        final streams = jsonData['streams'] as List<dynamic>;
        final audioTracks = <AudioTrack>[];

        int audioIndex = 0;

        for (final streamData in streams) {
          final streamMap = streamData as Map<String, dynamic>;

          if (streamMap['codec_type'] == 'audio') {
            final track = _parseAudioTrackFromJson(streamMap, audioIndex);
            if (track != null) {
              audioTracks.add(track);
              audioIndex++;
            }
          }
        }

        debugPrint('✅ Found ${audioTracks.length} audio tracks via JSON');
        return audioTracks;
      } catch (e) {
        debugPrint('❌ Error parsing JSON output: $e');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error in JSON analysis: $e');
      return [];
    }
  }

  // ✅ Parse audio track from JSON data
  static AudioTrack? _parseAudioTrackFromJson(
    Map<String, dynamic> streamData,
    int index,
  ) {
    try {
      // Extract language from tags
      String language = 'Unknown';
      final tags = streamData['tags'] as Map<String, dynamic>?;
      if (tags != null) {
        language = tags['language'] ?? tags['LANGUAGE'] ?? 'Unknown';
      }

      // Extract codec
      final codec =
          (streamData['codec_name'] as String?)?.toUpperCase() ?? 'Unknown';

      // Extract channels
      final channels = streamData['channels'] as int? ?? 2;

      // Extract bitrate
      int? bitrate;
      final bitrateStr = streamData['bit_rate'] as String?;
      if (bitrateStr != null) {
        bitrate = int.tryParse(bitrateStr);
      }

      // Extract title/label from tags
      String label = 'Track $index';
      if (tags != null) {
        label = tags['title'] ?? tags['TITLE'] ?? 'Track $index';
      }

      // Check if default from disposition
      bool isDefault = false;
      final disposition = streamData['disposition'] as Map<String, dynamic>?;
      if (disposition != null) {
        isDefault = disposition['default'] == 1;
      }

      return AudioTrack(
        id: index,
        language: _getLanguageName(language),
        label: '$label ($codec)',
        channels: channels,
        codec: codec,
        bitrate: bitrate,
        isDefault: isDefault,
      );
    } catch (e) {
      debugPrint('❌ Error parsing audio track from JSON $index: $e');
      return null;
    }
  }
}

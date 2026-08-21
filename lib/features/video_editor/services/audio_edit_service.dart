// STUB — P1: replaced by reel_editor audio system P6/P7
import '../../../core/utils/safe_async.dart';
import '../models/video_edit_settings.dart';

class AudioEditService {
  Future<Result<void>> initialize() async => Result.success(null);
  Future<Result<AudioInfo>> getAudioInfo(String path) async => Result.success(AudioInfo(duration: const Duration(seconds: 10)));
  Future<Result<String>> applyEcho({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> applyCompressor({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> enhanceVocals({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> removeNoise({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> applyBassBoost({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> applyTrebleBoost({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  Future<Result<String>> removeVocals({required String inputPath, void Function(double)? onProgress}) async => Result.success(inputPath);
  void dispose() {}
}

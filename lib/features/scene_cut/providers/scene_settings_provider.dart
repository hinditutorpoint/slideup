import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scene_settings.dart';
import '../services/scene_settings_service.dart';

class SceneSettingsNotifier extends Notifier<SceneSettings> {
  @override
  SceneSettings build() {
    return SceneSettingsService.instance.load();
  }

  Future<void> setPlatform(ScenePlatform platform) async {
    state = state.copyWith(platform: platform);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setContainer(SceneContainer container) async {
    state = state.copyWith(container: container);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setCustomResolution(int? w, int? h) async {
    state = state.copyWith(customWidth: w, customHeight: h);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> clearCustomResolution() async {
    state = state.copyWith(clearCustom: true);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setFitMode(SceneFit fit) async {
    state = state.copyWith(fitMode: fit);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setFps(int fps) async {
    state = state.copyWith(fps: fps);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setBitrate(int kbps) async {
    state = state.copyWith(videoBitrateKbps: kbps);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setAudioMode(SceneAudioMode mode) async {
    state = state.copyWith(audioMode: mode);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setSaveLocation(String path) async {
    state = state.copyWith(saveLocation: path);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setSaveDestination(SceneSaveDestination dest) async {
    state = state.copyWith(saveDestination: dest);
    await SceneSettingsService.instance.save(state);
  }

  Future<void> setFaststart(bool v) async {
    state = state.copyWith(faststart: v);
    await SceneSettingsService.instance.save(state);
  }
}

final sceneSettingsProvider = NotifierProvider<SceneSettingsNotifier, SceneSettings>(
  SceneSettingsNotifier.new,
);

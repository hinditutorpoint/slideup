import 'package:flutter_riverpod/legacy.dart';
import '../core/validation/numeric_guard.dart';
import '../models/reel_project.dart';

class OverlayNotifier extends StateNotifier<ReelProject?> {
  OverlayNotifier() : super(null);
  void Function(ReelProject)? onChanged;
  void load(ReelProject p) => state = p;
  void addText(ReelTextLayer t) {
    if (state == null) return;
    state = state!.copyWith(textLayers: [...state!.textLayers, t]);
    onChanged?.call(state!);
  }
  void updateText(String id, {String? text, double? fontSize, int? color, int? bgColor, String? fontFamily, double? x, double? y, double? scale, double? rotation, double? opacity}) {
    if (state == null) return;
    final list = [...state!.textLayers];
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = list[idx];
    list[idx] = ReelTextLayer(
      id: old.id, text: text ?? old.text, startTime: old.startTime, endTime: old.endTime,
      x: NumericGuard.sanitizeOpacity(x ?? old.x), y: NumericGuard.sanitizeOpacity(y ?? old.y),
      scale: NumericGuard.sanitizeScale(scale ?? old.scale), rotation: rotation ?? old.rotation,
      fontSize: fontSize ?? old.fontSize, fontFamily: fontFamily ?? old.fontFamily,
      color: color ?? old.color, bgColor: bgColor ?? old.bgColor, opacity: NumericGuard.sanitizeOpacity(opacity ?? old.opacity), zIndex: old.zIndex,
    );
    state = state!.copyWith(textLayers: list);
    onChanged?.call(state!);
  }
  void deleteText(String id) {
    if (state == null) return;
    state = state!.copyWith(textLayers: state!.textLayers.where((e) => e.id != id).toList());
    onChanged?.call(state!);
  }
  void addSticker(ReelStickerLayer s) {
    if (state == null) return;
    state = state!.copyWith(stickerLayers: [...state!.stickerLayers, s]);
    onChanged?.call(state!);
  }
  void addOverlay(ReelOverlayTrack o) {
    if (state == null) return;
    state = state!.copyWith(overlayTracks: [...state!.overlayTracks, o]);
    onChanged?.call(state!);
  }

  void updateSticker(String id, {double? scale, double? rotation, double? opacity, double? x, double? y}) {
    if (state == null) return;
    final list = [...state!.stickerLayers];
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = list[idx];
    list[idx] = ReelStickerLayer(
      id: old.id, asset: old.asset, startTime: old.startTime, endTime: old.endTime,
      x: x != null ? NumericGuard.sanitizeOpacity(x) : old.x,
      y: y != null ? NumericGuard.sanitizeOpacity(y) : old.y,
      scale: scale != null ? NumericGuard.sanitizeScale(scale) : old.scale,
      rotation: rotation ?? old.rotation,
      opacity: opacity != null ? NumericGuard.sanitizeOpacity(opacity) : old.opacity,
      zIndex: old.zIndex,
    );
    state = state!.copyWith(stickerLayers: list);
    onChanged?.call(state!);
  }

  void deleteSticker(String id) {
    if (state == null) return;
    state = state!.copyWith(stickerLayers: state!.stickerLayers.where((e) => e.id != id).toList());
    onChanged?.call(state!);
  }

  void updateOverlay(String id, {double? scale, double? rotation, double? opacity, double? x, double? y}) {
    if (state == null) return;
    final list = [...state!.overlayTracks];
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = list[idx];
    list[idx] = ReelOverlayTrack(
      id: old.id, imagePath: old.imagePath, startTime: old.startTime, endTime: old.endTime,
      x: x != null ? NumericGuard.sanitizeOpacity(x) : old.x,
      y: y != null ? NumericGuard.sanitizeOpacity(y) : old.y,
      scale: scale != null ? NumericGuard.sanitizeScale(scale) : old.scale,
      rotation: rotation ?? old.rotation,
      opacity: opacity != null ? NumericGuard.sanitizeOpacity(opacity) : old.opacity,
      zIndex: old.zIndex,
    );
    state = state!.copyWith(overlayTracks: list);
    onChanged?.call(state!);
  }

  void deleteOverlay(String id) {
    if (state == null) return;
    state = state!.copyWith(overlayTracks: state!.overlayTracks.where((e) => e.id != id).toList());
    onChanged?.call(state!);
  }
}

final overlayProvider = StateNotifierProvider<OverlayNotifier, ReelProject?>((_) => OverlayNotifier());

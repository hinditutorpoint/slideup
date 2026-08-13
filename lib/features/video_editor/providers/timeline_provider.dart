import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/video_edit_settings.dart';
import 'project_provider.dart';

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE STATE
// ═══════════════════════════════════════════════════════

@immutable
class TimelineState {
  final List<TextTimelineItem> textItems;
  final List<ImageTimelineItem> imageItems;
  final List<AudioTimelineItem> audioItems;
  final String? selectedItemId;
  final TimelineItemType? selectedItemType;
  final Set<String> selectedItemIds;
  final Duration currentPosition;
  final double zoomLevel;
  final bool isPlaying;
  final Duration totalDuration;
  final Set<String> lockedItems;
  final Set<String> hiddenItems;
  final List<Duration> markers;

  // ── Hybrid Magnetic Timeline ──────────────────────────
  /// Ordered sequence of primary video clips on the magnetic track.
  final List<PrimaryVideoClip> primaryVideoClips;

  const TimelineState({
    this.textItems = const [],
    this.imageItems = const [],
    this.audioItems = const [],
    this.selectedItemId,
    this.selectedItemType,
    this.selectedItemIds = const {},
    this.currentPosition = Duration.zero,
    this.zoomLevel = 1.0,
    this.isPlaying = false,
    this.totalDuration = Duration.zero,
    this.lockedItems = const {},
    this.hiddenItems = const {},
    this.markers = const [],
    this.primaryVideoClips = const [],
  });

  List<TimelineItem> get allItems {
    return [...textItems, ...imageItems, ...audioItems]
      ..sort((a, b) => a.layer.compareTo(b.layer));
  }

  TimelineItem? get selectedItem {
    if (selectedItemId == null) return null;

    for (final item in textItems) {
      if (item.id == selectedItemId) return item;
    }
    for (final item in imageItems) {
      if (item.id == selectedItemId) return item;
    }
    for (final item in audioItems) {
      if (item.id == selectedItemId) return item;
    }

    return null;
  }

  List<TimelineItem> get selectedItems {
    if (selectedItemIds.isEmpty) return [];
    return allItems.where((i) => selectedItemIds.contains(i.id)).toList();
  }

  List<TimelineItem> getVisibleItemsAt(Duration position) {
    return allItems.where((item) {
      if (hiddenItems.contains(item.id)) return false;
      return item.isVisibleAt(position);
    }).toList();
  }

  TimelineState copyWith({
    List<TextTimelineItem>? textItems,
    List<ImageTimelineItem>? imageItems,
    List<AudioTimelineItem>? audioItems,
    String? selectedItemId,
    TimelineItemType? selectedItemType,
    Set<String>? selectedItemIds,
    Duration? currentPosition,
    double? zoomLevel,
    bool? isPlaying,
    Duration? totalDuration,
    Set<String>? lockedItems,
    Set<String>? hiddenItems,
    List<Duration>? markers,
    List<PrimaryVideoClip>? primaryVideoClips,
  }) {
    return TimelineState(
      textItems: textItems ?? this.textItems,
      imageItems: imageItems ?? this.imageItems,
      audioItems: audioItems ?? this.audioItems,
      selectedItemId: selectedItemId ?? this.selectedItemId,
      selectedItemType: selectedItemType ?? this.selectedItemType,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      currentPosition: currentPosition ?? this.currentPosition,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isPlaying: isPlaying ?? this.isPlaying,
      totalDuration: totalDuration ?? this.totalDuration,
      lockedItems: lockedItems ?? this.lockedItems,
      hiddenItems: hiddenItems ?? this.hiddenItems,
      markers: markers ?? this.markers,
      primaryVideoClips: primaryVideoClips ?? this.primaryVideoClips,
    );
  }

  TimelineState clearSelection() {
    return TimelineState(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
      selectedItemId: null,
      selectedItemType: null,
      selectedItemIds: const {},
      currentPosition: currentPosition,
      zoomLevel: zoomLevel,
      isPlaying: isPlaying,
      totalDuration: totalDuration,
      lockedItems: lockedItems,
      hiddenItems: hiddenItems,
      markers: markers,
      primaryVideoClips: primaryVideoClips,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE NOTIFIER
// ═══════════════════════════════════════════════════════

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier(this._projectNotifier) : super(const TimelineState());

  final ProjectNotifier _projectNotifier;
  final _uuid = const Uuid();

  // ═══════════════════════════════════════════════════════
  // ✅ LOAD FROM PROJECT
  // ═══════════════════════════════════════════════════════

  void loadFromProject(VideoProject project) {
    state = state.copyWith(
      textItems: project.textItems,
      imageItems: project.imageItems,
      audioItems: project.audioItems,
      totalDuration: project.magneticTrackDuration,
      currentPosition: Duration.zero,
      selectedItemId: null,
      selectedItemType: null,
      selectedItemIds: const {},
      markers: project.markers,
      primaryVideoClips: project.primaryVideoClips,
    );
  }

  void syncToProject() {
    final currentProject = _projectNotifier.state.currentProject;
    if (currentProject == null) return;

    _projectNotifier.updateCurrentProject(
      currentProject.copyWith(
        textItems: state.textItems,
        imageItems: state.imageItems,
        audioItems: state.audioItems,
        markers: state.markers,
        primaryVideoClips: state.primaryVideoClips,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HYBRID MAGNETIC TIMELINE – RIPPLE ENGINE
  // ═══════════════════════════════════════════════════════

  /// Appends [clip] to the end of the primary magnetic track.
  void addPrimaryClip(PrimaryVideoClip clip) {
    try {
      final clips = [...state.primaryVideoClips, clip];
      final project = _projectNotifier.state.currentProject;
      final newDuration = _calcMagneticDuration(clips);
      state = state.copyWith(
        primaryVideoClips: clips,
        totalDuration: newDuration,
      );
      if (project != null) {
        _projectNotifier.updateCurrentProject(
          project.copyWith(
            primaryVideoClips: clips,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ addPrimaryClip error: $e');
    }
  }

  /// Ripple Trim: changes the effective duration of [clipId].
  /// All downstream clips and overlay items automatically shift.
  void rippleTrimPrimaryClip(
    String clipId, {
    Duration? newTrimStart,
    Duration? newTrimEnd,
  }) {
    try {
      final clips = state.primaryVideoClips.toList();
      final idx = clips.indexWhere((c) => c.id == clipId);
      if (idx < 0) return;

      final oldClip = clips[idx];
      final oldEffective = oldClip.effectiveDuration;
      final updatedClip = oldClip.copyWith(
        trimStart: newTrimStart,
        trimEnd: newTrimEnd,
      );
      final delta = updatedClip.effectiveDuration - oldEffective;
      clips[idx] = updatedClip;

      // Shift secondary overlay items that start after the clip boundary
      final clipAbsStart = _calcStartTimeAt(clips, idx);
      final shiftFrom = clipAbsStart + oldEffective;

      final shiftedText = state.textItems.map((item) {
        if (item.startTime >= shiftFrom) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final shiftedImage = state.imageItems.map((item) {
        if (item.startTime >= shiftFrom) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final shiftedAudio = state.audioItems.map((item) {
        if (item.startTime >= shiftFrom) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final newDuration = _calcMagneticDuration(clips);
      state = state.copyWith(
        primaryVideoClips: clips,
        textItems: shiftedText,
        imageItems: shiftedImage,
        audioItems: shiftedAudio,
        totalDuration: newDuration,
      );
      syncToProject();
    } catch (e) {
      debugPrint('❌ rippleTrimPrimaryClip error: $e');
    }
  }

  /// Ripple Delete: removes [clipId] and collapses the gap automatically.
  void rippleDeletePrimaryClip(String clipId) {
    try {
      final clips = state.primaryVideoClips.toList();
      final idx = clips.indexWhere((c) => c.id == clipId);
      if (idx < 0) return;

      final clipAbsStart = _calcStartTimeAt(clips, idx);
      final deletedDuration = clips[idx].effectiveDuration;
      final shiftFrom = clipAbsStart;
      final delta = -deletedDuration;
      clips.removeAt(idx);

      // Shift all secondary overlay items after the deleted clip
      final shiftedText = state.textItems.map((item) {
        if (item.startTime >= shiftFrom + deletedDuration) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final shiftedImage = state.imageItems.map((item) {
        if (item.startTime >= shiftFrom + deletedDuration) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final shiftedAudio = state.audioItems.map((item) {
        if (item.startTime >= shiftFrom + deletedDuration) {
          return item.copyWith(
            startTime: item.startTime + delta,
            endTime: item.endTime + delta,
          );
        }
        return item;
      }).toList();

      final newDuration = _calcMagneticDuration(clips);
      state = state.copyWith(
        primaryVideoClips: clips,
        textItems: shiftedText,
        imageItems: shiftedImage,
        audioItems: shiftedAudio,
        totalDuration: newDuration,
      );
      syncToProject();
    } catch (e) {
      debugPrint('❌ rippleDeletePrimaryClip error: $e');
    }
  }

  /// Reorders clips on the magnetic track (drag-and-drop).
  void reorderPrimaryClips(int oldIndex, int newIndex) {
    try {
      final clips = state.primaryVideoClips.toList();
      if (oldIndex < 0 ||
          oldIndex >= clips.length ||
          newIndex < 0 ||
          newIndex >= clips.length) {
        return;
      }
      final clip = clips.removeAt(oldIndex);
      clips.insert(newIndex, clip);
      final newDuration = _calcMagneticDuration(clips);
      state = state.copyWith(
        primaryVideoClips: clips,
        totalDuration: newDuration,
      );
      syncToProject();
    } catch (e) {
      debugPrint('❌ reorderPrimaryClips error: $e');
    }
  }

  /// Sets the outgoing transition for the clip at [clipIndex].
  void setClipTransition(int clipIndex, ClipTransition transition) {
    try {
      final clips = state.primaryVideoClips.toList();
      if (clipIndex < 0 || clipIndex >= clips.length - 1) return;
      clips[clipIndex] = clips[clipIndex].copyWith(
        transitionOut: transition,
      );
      final newDuration = _calcMagneticDuration(clips);
      state = state.copyWith(
        primaryVideoClips: clips,
        totalDuration: newDuration,
      );
      syncToProject();
    } catch (e) {
      debugPrint('❌ setClipTransition error: $e');
    }
  }

  // ── Private ripple helpers ─────────────────────────────

  Duration _calcMagneticDuration(List<PrimaryVideoClip> clips) {
    try {
      Duration total = Duration.zero;
      for (int i = 0; i < clips.length; i++) {
        total += clips[i].effectiveDuration;
        if (i < clips.length - 1) {
          final t = clips[i].transitionOut;
          if (t.hasTransition) total -= t.duration;
        }
      }
      return total < Duration.zero ? Duration.zero : total;
    } catch (_) {
      return Duration.zero;
    }
  }

  Duration _calcStartTimeAt(List<PrimaryVideoClip> clips, int index) {
    try {
      Duration start = Duration.zero;
      for (int i = 0; i < index; i++) {
        start += clips[i].effectiveDuration;
        if (i < clips.length - 1) {
          final t = clips[i].transitionOut;
          if (t.hasTransition) start -= t.duration;
        }
      }
      return start;
    } catch (_) {
      return Duration.zero;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK
  // ═══════════════════════════════════════════════════════

  void setCurrentPosition(Duration position) {
    state = state.copyWith(currentPosition: position);
  }

  void setPlaying(bool playing) {
    state = state.copyWith(isPlaying: playing);
  }

  void setZoomLevel(double zoom) {
    state = state.copyWith(zoomLevel: zoom.clamp(0.1, 10.0));
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SELECTION
  // ═══════════════════════════════════════════════════════

  void selectItem(String? itemId, [TimelineItemType? type]) {
    state = state.copyWith(
      selectedItemId: itemId,
      selectedItemType: type,
      selectedItemIds: {if (itemId != null) itemId},
    );
  }

  void toggleSelectItem(String itemId, TimelineItemType type) {
    final ids = Set<String>.from(state.selectedItemIds);
    if (!ids.add(itemId)) {
      ids.remove(itemId);
    }
    state = state.copyWith(
      selectedItemId: ids.contains(itemId) ? itemId : state.selectedItemId,
      selectedItemType: type,
      selectedItemIds: ids,
    );
  }

  void clearSelection() {
    state = state.clearSelection();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GROUP OPERATIONS
  // ═══════════════════════════════════════════════════════

  void groupSelectedItems() {
    final selectedIds = state.selectedItemIds;
    if (selectedIds.isEmpty) return;

    final groupId = _uuid.v4();

    var textItems = state.textItems;
    var imageItems = state.imageItems;
    var audioItems = state.audioItems;

    textItems = textItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: groupId)
            : e)
        .toList();
    imageItems = imageItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: groupId)
            : e)
        .toList();
    audioItems = audioItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: groupId)
            : e)
        .toList();

    state = state.copyWith(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
    );
    syncToProject();
  }

  void ungroupSelectedItems() {
    final selectedIds = state.selectedItemIds;
    if (selectedIds.isEmpty) return;

    var textItems = state.textItems;
    var imageItems = state.imageItems;
    var audioItems = state.audioItems;

    textItems = textItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: null)
            : e)
        .toList();
    imageItems = imageItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: null)
            : e)
        .toList();
    audioItems = audioItems
        .map((e) => selectedIds.contains(e.id)
            ? e.copyWith(groupId: null)
            : e)
        .toList();

    state = state.copyWith(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
    );
    syncToProject();
  }

  /// Select every item that shares a group with [itemId].
  void selectGroup(String itemId) {
    TimelineItem? item;
    for (final i in state.allItems) {
      if (i.id == itemId) {
        item = i;
        break;
      }
    }
    if (item == null) return;
    final groupId = item.groupId;
    if (groupId == null) {
      selectItem(itemId, item.type);
      return;
    }

    final ids = state.allItems
        .where((i) => i.groupId == groupId)
        .map((i) => i.id)
        .toSet();
    state = state.copyWith(
      selectedItemId: itemId,
      selectedItemType: item.type,
      selectedItemIds: ids,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MARKERS
  // ═══════════════════════════════════════════════════════

  void addMarker([Duration? position]) {
    final marker = position ?? state.currentPosition;
    final markers = List<Duration>.from(state.markers)..add(marker);
    markers.sort((a, b) => a.compareTo(b));
    state = state.copyWith(markers: markers);
    syncToProject();
  }

  void removeMarkerAt(Duration position) {
    final markers = List<Duration>.from(state.markers);
    markers.removeWhere(
      (m) => (m - position).inMilliseconds.abs() < 500,
    );
    state = state.copyWith(markers: markers);
    syncToProject();
  }

  void clearMarkers() {
    state = state.copyWith(markers: const []);
    syncToProject();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TEXT ITEMS
  // ═══════════════════════════════════════════════════════

  void addTextItem({
    required String text,
    Duration? startTime,
    Duration? duration,
    TextOverlayStyle? style,
    double x = 0.5,
    double y = 0.8,
  }) {
    final item = TextTimelineItem.create(
      id: _uuid.v4(),
      text: text,
      startTime: startTime ?? state.currentPosition,
      endTime:
          (startTime ?? state.currentPosition) +
          (duration ?? const Duration(seconds: 3)),
      style: style ?? const TextOverlayStyle(),
      x: x,
      y: y,
      layer: _getNextLayer(TimelineItemType.text),
    );

    state = state.copyWith(
      textItems: [...state.textItems, item],
      selectedItemId: item.id,
      selectedItemType: TimelineItemType.text,
      selectedItemIds: {item.id},
    );

    syncToProject();
  }

  void updateTextItem(String itemId, TextTimelineItem updatedItem) {
    final items = state.textItems.map((item) {
      return item.id == itemId ? updatedItem : item;
    }).toList();

    state = state.copyWith(textItems: items);
    syncToProject();
  }

  void removeTextItem(String itemId) {
    final items = state.textItems.where((item) => item.id != itemId).toList();
    final ids = Set<String>.from(state.selectedItemIds)..remove(itemId);
    state = state.copyWith(
      textItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
      selectedItemIds: ids,
    );
    syncToProject();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ IMAGE ITEMS
  // ═══════════════════════════════════════════════════════

  void addImageItem({
    required String imagePath,
    Duration? startTime,
    Duration? duration,
    double x = 0.5,
    double y = 0.5,
    double scale = 0.3,
    int? width,
    int? height,
  }) {
    final item = ImageTimelineItem.create(
      id: _uuid.v4(),
      imagePath: imagePath,
      startTime: startTime ?? state.currentPosition,
      endTime:
          (startTime ?? state.currentPosition) +
          (duration ?? const Duration(seconds: 3)),
      x: x,
      y: y,
      scale: scale,
      width: width ?? 1920,
      height: height ?? 1080,
      layer: _getNextLayer(TimelineItemType.image),
    );

    state = state.copyWith(
      imageItems: [...state.imageItems, item],
      selectedItemId: item.id,
      selectedItemType: TimelineItemType.image,
      selectedItemIds: {item.id},
    );

    syncToProject();
  }

  void addGeneratedImage(ImageTimelineItem item) {
    final withLayer = item.copyWith(
      layer: _getNextLayer(TimelineItemType.image),
    );

    state = state.copyWith(
      imageItems: [...state.imageItems, withLayer],
      selectedItemId: withLayer.id,
      selectedItemType: TimelineItemType.image,
      selectedItemIds: {withLayer.id},
    );

    syncToProject();
  }

  void updateImageItem(String itemId, ImageTimelineItem updatedItem) {
    final items = state.imageItems.map((item) {
      return item.id == itemId ? updatedItem : item;
    }).toList();

    state = state.copyWith(imageItems: items);
    syncToProject();
  }

  void removeImageItem(String itemId) {
    final items = state.imageItems.where((item) => item.id != itemId).toList();
    final ids = Set<String>.from(state.selectedItemIds)..remove(itemId);
    state = state.copyWith(
      imageItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
      selectedItemIds: ids,
    );
    syncToProject();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ AUDIO ITEMS
  // ═══════════════════════════════════════════════════════

  void addAudioItem({
    required String audioPath,
    required Duration audioDuration,
    Duration? startTime,
    String title = '',
    String artist = '',
    double volume = 1.0,
  }) {
    final item = AudioTimelineItem.create(
      id: _uuid.v4(),
      audioPath: audioPath,
      audioDuration: audioDuration,
      startTime: startTime ?? state.currentPosition,
      endTime: (startTime ?? state.currentPosition) + audioDuration,
      title: title,
      artist: artist,
      volume: volume,
      layer: _getNextLayer(TimelineItemType.audio),
    );

    state = state.copyWith(
      audioItems: [...state.audioItems, item],
      selectedItemId: item.id,
      selectedItemType: TimelineItemType.audio,
      selectedItemIds: {item.id},
    );

    syncToProject();
  }

  void updateAudioItem(String itemId, AudioTimelineItem updatedItem) {
    final items = state.audioItems.map((item) {
      return item.id == itemId ? updatedItem : item;
    }).toList();

    state = state.copyWith(audioItems: items);
    syncToProject();
  }

  void removeAudioItem(String itemId) {
    final items = state.audioItems.where((item) => item.id != itemId).toList();
    final ids = Set<String>.from(state.selectedItemIds)..remove(itemId);
    state = state.copyWith(
      audioItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
      selectedItemIds: ids,
    );
    syncToProject();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ITEM OPERATIONS
  // ═══════════════════════════════════════════════════════

  void moveItem(String itemId, Duration newStartTime) {
    // Find and update item
    for (int i = 0; i < state.textItems.length; i++) {
      if (state.textItems[i].id == itemId) {
        final item = state.textItems[i];
        final duration = item.duration;
        updateTextItem(
          itemId,
          item.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + duration,
          ),
        );
        return;
      }
    }

    for (int i = 0; i < state.imageItems.length; i++) {
      if (state.imageItems[i].id == itemId) {
        final item = state.imageItems[i];
        final duration = item.duration;
        updateImageItem(
          itemId,
          item.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + duration,
          ),
        );
        return;
      }
    }

    for (int i = 0; i < state.audioItems.length; i++) {
      if (state.audioItems[i].id == itemId) {
        final item = state.audioItems[i];
        final duration = item.duration;
        updateAudioItem(
          itemId,
          item.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + duration,
          ),
        );
        return;
      }
    }
  }

  void resizeItem(String itemId, Duration newDuration) {
    for (int i = 0; i < state.textItems.length; i++) {
      if (state.textItems[i].id == itemId) {
        final item = state.textItems[i];
        updateTextItem(
          itemId,
          item.copyWith(endTime: item.startTime + newDuration),
        );
        return;
      }
    }

    for (int i = 0; i < state.imageItems.length; i++) {
      if (state.imageItems[i].id == itemId) {
        final item = state.imageItems[i];
        updateImageItem(
          itemId,
          item.copyWith(endTime: item.startTime + newDuration),
        );
        return;
      }
    }

    for (int i = 0; i < state.audioItems.length; i++) {
      if (state.audioItems[i].id == itemId) {
        final item = state.audioItems[i];
        updateAudioItem(
          itemId,
          item.copyWith(endTime: item.startTime + newDuration),
        );
        return;
      }
    }
  }

  /// Move all selected (or group-shared) items together by [delta],
  /// clamping so no item exceeds the total timeline duration.
  void moveSelectedItems(Duration delta) {
    final ids = state.selectedItemIds;
    if (ids.isEmpty) return;

    final canMove = ids.every((id) {
      final item = _findItem(id);
      if (item == null) return true;
      final newStart = item.startTime + delta;
      return newStart >= Duration.zero &&
          newStart + item.duration <= state.totalDuration;
    });
    if (!canMove) return;

    var textItems = state.textItems;
    var imageItems = state.imageItems;
    var audioItems = state.audioItems;

    textItems = textItems.map((e) {
      if (!ids.contains(e.id)) return e;
      return e.copyWith(
        startTime: e.startTime + delta,
        endTime: e.endTime + delta,
      );
    }).toList();
    imageItems = imageItems.map((e) {
      if (!ids.contains(e.id)) return e;
      return e.copyWith(
        startTime: e.startTime + delta,
        endTime: e.endTime + delta,
      );
    }).toList();
    audioItems = audioItems.map((e) {
      if (!ids.contains(e.id)) return e;
      return e.copyWith(
        startTime: e.startTime + delta,
        endTime: e.endTime + delta,
      );
    }).toList();

    state = state.copyWith(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
    );
    syncToProject();
  }

  void deleteSelectedItems() {
    final ids = state.selectedItemIds;
    if (ids.isEmpty) return;

    state = state.copyWith(
      textItems: state.textItems
          .where((e) => !ids.contains(e.id))
          .toList(),
      imageItems: state.imageItems
          .where((e) => !ids.contains(e.id))
          .toList(),
      audioItems: state.audioItems
          .where((e) => !ids.contains(e.id))
          .toList(),
      selectedItemId: null,
      selectedItemType: null,
      selectedItemIds: const {},
    );
    syncToProject();
  }

  TimelineItem? _findItem(String id) {
    for (final e in state.textItems) {
      if (e.id == id) return e;
    }
    for (final e in state.imageItems) {
      if (e.id == id) return e;
    }
    for (final e in state.audioItems) {
      if (e.id == id) return e;
    }
    return null;
  }

  void duplicateItem(String itemId) {
    for (final item in state.textItems) {
      if (item.id == itemId) {
        addTextItem(
          text: item.text,
          startTime: item.startTime + const Duration(milliseconds: 500),
          duration: item.duration,
          style: item.style,
          x: item.x,
          y: item.y,
        );
        return;
      }
    }

    for (final item in state.imageItems) {
      if (item.id == itemId) {
        addImageItem(
          imagePath: item.imagePath,
          startTime: item.startTime + const Duration(milliseconds: 500),
          duration: item.duration,
          x: item.x,
          y: item.y,
          scale: item.scale,
        );
        return;
      }
    }

    for (final item in state.audioItems) {
      if (item.id == itemId) {
        addAudioItem(
          audioPath: item.audioPath,
          audioDuration: item.audioDuration,
          startTime: item.startTime + const Duration(milliseconds: 500),
          title: item.title,
          artist: item.artist,
          volume: item.volume,
        );
        return;
      }
    }
  }

  void deleteSelectedItem() {
    if (state.selectedItemId == null) return;

    switch (state.selectedItemType) {
      case TimelineItemType.text:
        removeTextItem(state.selectedItemId!);
        break;
      case TimelineItemType.image:
        removeImageItem(state.selectedItemId!);
        break;
      case TimelineItemType.audio:
        removeAudioItem(state.selectedItemId!);
        break;
      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LOCK/HIDE ITEMS
  // ═══════════════════════════════════════════════════════

  void toggleLockItem(String itemId) {
    final lockedItems = Set<String>.from(state.lockedItems);
    if (lockedItems.contains(itemId)) {
      lockedItems.remove(itemId);
    } else {
      lockedItems.add(itemId);
    }
    state = state.copyWith(lockedItems: lockedItems);
  }

  void toggleHideItem(String itemId) {
    final hiddenItems = Set<String>.from(state.hiddenItems);
    if (hiddenItems.contains(itemId)) {
      hiddenItems.remove(itemId);
    } else {
      hiddenItems.add(itemId);
    }
    state = state.copyWith(hiddenItems: hiddenItems);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LAYER MANAGEMENT
  // ═══════════════════════════════════════════════════════

  int _getNextLayer(TimelineItemType type) {
    int maxLayer = 0;

    switch (type) {
      case TimelineItemType.text:
        for (final item in state.textItems) {
          if (item.layer > maxLayer) maxLayer = item.layer;
        }
        break;
      case TimelineItemType.image:
        for (final item in state.imageItems) {
          if (item.layer > maxLayer) maxLayer = item.layer;
        }
        break;
      case TimelineItemType.audio:
        for (final item in state.audioItems) {
          if (item.layer > maxLayer) maxLayer = item.layer;
        }
        break;
      default:
        break;
    }

    return maxLayer + 1;
  }

  void bringToFront(String itemId) {
    final maxLayer = _getMaxLayer();

    for (int i = 0; i < state.textItems.length; i++) {
      if (state.textItems[i].id == itemId) {
        updateTextItem(
          itemId,
          state.textItems[i].copyWith(layer: maxLayer + 1),
        );
        return;
      }
    }

    for (int i = 0; i < state.imageItems.length; i++) {
      if (state.imageItems[i].id == itemId) {
        updateImageItem(
          itemId,
          state.imageItems[i].copyWith(layer: maxLayer + 1),
        );
        return;
      }
    }
  }

  void sendToBack(String itemId) {
    final minLayer = _getMinLayer();

    for (int i = 0; i < state.textItems.length; i++) {
      if (state.textItems[i].id == itemId) {
        updateTextItem(
          itemId,
          state.textItems[i].copyWith(layer: minLayer - 1),
        );
        return;
      }
    }

    for (int i = 0; i < state.imageItems.length; i++) {
      if (state.imageItems[i].id == itemId) {
        updateImageItem(
          itemId,
          state.imageItems[i].copyWith(layer: minLayer - 1),
        );
        return;
      }
    }
  }

  void reorderItems(int oldIndex, int newIndex) {
    final items = List<TimelineItem>.from(state.allItems);
    if (items.isEmpty || oldIndex < 0 || oldIndex >= items.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex > items.length) return;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    var textItems = state.textItems;
    var imageItems = state.imageItems;
    var audioItems = state.audioItems;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final layer = i;
      if (item is TextTimelineItem) {
        textItems = textItems
            .map((e) => e.id == item.id ? e.copyWith(layer: layer) : e)
            .toList();
      } else if (item is ImageTimelineItem) {
        imageItems = imageItems
            .map((e) => e.id == item.id ? e.copyWith(layer: layer) : e)
            .toList();
      } else if (item is AudioTimelineItem) {
        audioItems = audioItems
            .map((e) => e.id == item.id ? e.copyWith(layer: layer) : e)
            .toList();
      }
    }

    state = state.copyWith(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
    );
    syncToProject();
  }

  int _getMaxLayer() {
    int max = 0;
    for (final item in state.allItems) {
      if (item.layer > max) max = item.layer;
    }
    return max;
  }

  int _getMinLayer() {
    int min = 0;
    for (final item in state.allItems) {
      if (item.layer < min) min = item.layer;
    }
    return min;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLEAR
  // ═══════════════════════════════════════════════════════

  void clearAll() {
    state = const TimelineState();
    syncToProject();
  }

  void clearAllText() {
    state = state.copyWith(textItems: []);
    syncToProject();
  }

  void clearAllImages() {
    state = state.copyWith(imageItems: []);
    syncToProject();
  }

  void clearAllAudio() {
    state = state.copyWith(audioItems: []);
    syncToProject();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>(
  (ref) {
    final projectNotifier = ref.watch(projectProvider.notifier);
    return TimelineNotifier(projectNotifier);
  },
);

// Convenience providers
final selectedItemProvider = Provider<TimelineItem?>((ref) {
  return ref.watch(timelineProvider).selectedItem;
});

final currentPositionProvider = Provider<Duration>((ref) {
  return ref.watch(timelineProvider).currentPosition;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(timelineProvider).isPlaying;
});

final zoomLevelProvider = Provider<double>((ref) {
  return ref.watch(timelineProvider).zoomLevel;
});

final textItemsProvider = Provider<List<TextTimelineItem>>((ref) {
  return ref.watch(timelineProvider).textItems;
});

final imageItemsProvider = Provider<List<ImageTimelineItem>>((ref) {
  return ref.watch(timelineProvider).imageItems;
});

final audioItemsProvider = Provider<List<AudioTimelineItem>>((ref) {
  return ref.watch(timelineProvider).audioItems;
});

final allItemsProvider = Provider<List<TimelineItem>>((ref) {
  return ref.watch(timelineProvider).allItems;
});

final selectedItemIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(timelineProvider).selectedItemIds;
});

final markersProvider = Provider<List<Duration>>((ref) {
  return ref.watch(timelineProvider).markers;
});

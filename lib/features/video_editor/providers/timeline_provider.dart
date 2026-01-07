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
  final Duration currentPosition;
  final double zoomLevel;
  final bool isPlaying;
  final Duration totalDuration;
  final Set<String> lockedItems;
  final Set<String> hiddenItems;

  const TimelineState({
    this.textItems = const [],
    this.imageItems = const [],
    this.audioItems = const [],
    this.selectedItemId,
    this.selectedItemType,
    this.currentPosition = Duration.zero,
    this.zoomLevel = 1.0,
    this.isPlaying = false,
    this.totalDuration = Duration.zero,
    this.lockedItems = const {},
    this.hiddenItems = const {},
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
    Duration? currentPosition,
    double? zoomLevel,
    bool? isPlaying,
    Duration? totalDuration,
    Set<String>? lockedItems,
    Set<String>? hiddenItems,
  }) {
    return TimelineState(
      textItems: textItems ?? this.textItems,
      imageItems: imageItems ?? this.imageItems,
      audioItems: audioItems ?? this.audioItems,
      selectedItemId: selectedItemId ?? this.selectedItemId,
      selectedItemType: selectedItemType ?? this.selectedItemType,
      currentPosition: currentPosition ?? this.currentPosition,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isPlaying: isPlaying ?? this.isPlaying,
      totalDuration: totalDuration ?? this.totalDuration,
      lockedItems: lockedItems ?? this.lockedItems,
      hiddenItems: hiddenItems ?? this.hiddenItems,
    );
  }

  TimelineState clearSelection() {
    return TimelineState(
      textItems: textItems,
      imageItems: imageItems,
      audioItems: audioItems,
      selectedItemId: null,
      selectedItemType: null,
      currentPosition: currentPosition,
      zoomLevel: zoomLevel,
      isPlaying: isPlaying,
      totalDuration: totalDuration,
      lockedItems: lockedItems,
      hiddenItems: hiddenItems,
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
      totalDuration: project.effectiveDuration,
      currentPosition: Duration.zero,
      selectedItemId: null,
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
      ),
    );
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
    state = state.copyWith(selectedItemId: itemId, selectedItemType: type);
  }

  void clearSelection() {
    state = state.clearSelection();
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
    state = state.copyWith(
      textItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
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
    state = state.copyWith(
      imageItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
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
    state = state.copyWith(
      audioItems: items,
      selectedItemId: state.selectedItemId == itemId
          ? null
          : state.selectedItemId,
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

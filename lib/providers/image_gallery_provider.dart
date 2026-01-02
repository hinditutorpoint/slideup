import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';

class ImageGalleryState {
  final bool isSelectionMode;
  final Set<String> selectedImageIds;
  final bool isDeleting;

  const ImageGalleryState({
    this.isSelectionMode = false,
    this.selectedImageIds = const {},
    this.isDeleting = false,
  });

  ImageGalleryState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedImageIds,
    bool? isDeleting,
  }) {
    return ImageGalleryState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedImageIds: selectedImageIds ?? this.selectedImageIds,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  int get selectedCount => selectedImageIds.length;
  bool isSelected(String imageId) => selectedImageIds.contains(imageId);
}

class ImageGalleryNotifier extends Notifier<ImageGalleryState> {

  @override
  ImageGalleryState build() {
    return const ImageGalleryState();
  }

  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  void exitSelectionMode() {
    state = const ImageGalleryState(
      isSelectionMode: false,
      selectedImageIds: {},
    );
  }

  void toggleSelection(String imageId) {
    final newSelection = Set<String>.from(state.selectedImageIds);
    
    if (newSelection.contains(imageId)) {
      newSelection.remove(imageId);
    } else {
      newSelection.add(imageId);
    }

    state = state.copyWith(selectedImageIds: newSelection);

    // Auto-exit selection mode if no items selected
    if (newSelection.isEmpty) {
      exitSelectionMode();
    }
  }

  void selectAll(List<MediaFile> images) {
    final allIds = images.map((img) => img.id).toSet();
    state = state.copyWith(
      isSelectionMode: true,
      selectedImageIds: allIds,
    );
  }

  void deselectAll() {
    state = state.copyWith(selectedImageIds: {});
  }

  void setDeleting(bool isDeleting) {
    state = state.copyWith(isDeleting: isDeleting);
  }
}

final imageGalleryProvider =
    NotifierProvider.autoDispose<ImageGalleryNotifier, ImageGalleryState>(
  () => ImageGalleryNotifier(),
);
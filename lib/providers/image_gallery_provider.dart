import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';

class ImageGalleryState {
  final bool isSelectionMode;
  final Set<String> selectedImageIds;
  final bool isDeleting;
  final String searchQuery;
  final bool isSearchMode;

  const ImageGalleryState({
    this.isSelectionMode = false,
    this.selectedImageIds = const {},
    this.isDeleting = false,
    this.searchQuery = '',
    this.isSearchMode = false,
  });

  ImageGalleryState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedImageIds,
    bool? isDeleting,
    String? searchQuery,
    bool? isSearchMode,
  }) {
    return ImageGalleryState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedImageIds: selectedImageIds ?? this.selectedImageIds,
      isDeleting: isDeleting ?? this.isDeleting,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchMode: isSearchMode ?? this.isSearchMode,
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
    state = state.copyWith(
      isSelectionMode: true,
      isSearchMode: false,
      searchQuery: '',
    );
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
    state = state.copyWith(isSelectionMode: true, selectedImageIds: allIds);
  }

  void deselectAll() {
    state = state.copyWith(selectedImageIds: {});
  }

  void setDeleting(bool isDeleting) {
    state = state.copyWith(isDeleting: isDeleting);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleSearchMode() {
    final newSearchMode = !state.isSearchMode;
    if (!newSearchMode) {
      state = state.copyWith(isSearchMode: false, searchQuery: '');
    } else {
      state = state.copyWith(isSearchMode: true);
    }
  }

  void exitSearchMode() {
    state = state.copyWith(isSearchMode: false, searchQuery: '');
  }
}

final imageGalleryProvider =
    NotifierProvider.autoDispose<ImageGalleryNotifier, ImageGalleryState>(
      () => ImageGalleryNotifier(),
    );

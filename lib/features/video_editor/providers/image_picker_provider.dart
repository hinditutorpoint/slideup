import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';

import '../models/video_edit_settings.dart';
import '../services/pixabay_api_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ IMAGE PICKER STATE
// ═══════════════════════════════════════════════════════

@immutable
class ImagePickerState {
  final List<StockImage> images;
  final List<StockImage> downloadedImages;
  final List<StockImage> selectedImages;
  final Map<String, double> downloadProgress;
  final ImageCategory selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool showDownloaded;

  const ImagePickerState({
    this.images = const [],
    this.downloadedImages = const [],
    this.selectedImages = const [],
    this.downloadProgress = const {},
    this.selectedCategory = ImageCategory.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.showDownloaded = false,
  });

  ImagePickerState copyWith({
    List<StockImage>? images,
    List<StockImage>? downloadedImages,
    List<StockImage>? selectedImages,
    Map<String, double>? downloadProgress,
    ImageCategory? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? showDownloaded,
  }) {
    return ImagePickerState(
      images: images ?? this.images,
      downloadedImages: downloadedImages ?? this.downloadedImages,
      selectedImages: selectedImages ?? this.selectedImages,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      showDownloaded: showDownloaded ?? this.showDownloaded,
    );
  }

  List<StockImage> get filteredImages {
    if (showDownloaded) {
      if (searchQuery.isEmpty) return downloadedImages;
      final q = searchQuery.toLowerCase();
      return downloadedImages
          .where(
            (i) =>
                i.title.toLowerCase().contains(q) ||
                i.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    return images;
  }
}

// ═══════════════════════════════════════════════════════
// ✅ IMAGE PICKER NOTIFIER
// ═══════════════════════════════════════════════════════

class ImagePickerNotifier extends StateNotifier<ImagePickerState> {
  ImagePickerNotifier(this._apiService) : super(const ImagePickerState()) {
    _init();
  }

  final PixabayApiService _apiService;

  void _init() {
    loadImages();
    loadDownloadedImages();
  }

  // Load images
  Future<void> loadImages({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 1 : state.currentPage,
    );

    try {
      final images = await _apiService.fetchImages(
        query: state.searchQuery,
        category: state.selectedCategory,
        page: refresh ? 1 : state.currentPage,
        perPage: 30,
      );

      state = state.copyWith(
        images: refresh ? images : [...state.images, ...images],
        isLoading: false,
        currentPage: state.currentPage + (refresh ? 0 : 1),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load images', isLoading: false);
    }
  }

  // Load more images
  Future<void> loadMoreImages() async {
    if (state.isLoadingMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final images = await _apiService.fetchImages(
        query: state.searchQuery,
        category: state.selectedCategory,
        page: state.currentPage + 1,
        perPage: 30,
      );

      if (images.isNotEmpty) {
        state = state.copyWith(
          images: [...state.images, ...images],
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      debugPrint('Load more error: $e');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // Load downloaded images
  Future<void> loadDownloadedImages() async {
    try {
      final downloaded = await _apiService.getDownloadedImages();
      state = state.copyWith(downloadedImages: downloaded);
    } catch (e) {
      debugPrint('Load downloaded error: $e');
    }
  }

  // Set category
  void setCategory(ImageCategory category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(
      selectedCategory: category,
      currentPage: 1,
      images: [],
    );
    loadImages(refresh: true);
  }

  // Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    if (!state.showDownloaded) {
      loadImages(refresh: true);
    }
  }

  // Toggle view mode
  void toggleViewMode(bool showDownloaded) {
    state = state.copyWith(showDownloaded: showDownloaded);
    if (showDownloaded) {
      loadDownloadedImages();
    }
  }

  // Select/deselect image
  void toggleImageSelection(StockImage image) {
    final selected = List<StockImage>.from(state.selectedImages);
    final index = selected.indexWhere((i) => i.id == image.id);

    if (index >= 0) {
      selected.removeAt(index);
    } else {
      selected.add(image);
    }

    state = state.copyWith(selectedImages: selected);
  }

  // Clear selection
  void clearSelection() {
    state = state.copyWith(selectedImages: []);
  }

  // Download image
  Future<void> downloadImage(StockImage image) async {
    final progress = Map<String, double>.from(state.downloadProgress);
    progress[image.id] = 0;
    state = state.copyWith(downloadProgress: progress);

    try {
      final result = await _apiService.downloadImage(
        image,
        onProgress: (p) {
          final prog = Map<String, double>.from(state.downloadProgress);
          prog[image.id] = p;
          state = state.copyWith(downloadProgress: prog);
        },
      );

      if (result != null) {
        // Update image in list
        final images = state.images.map((i) {
          if (i.id == image.id) return result;
          return i;
        }).toList();

        state = state.copyWith(images: images);
        await loadDownloadedImages();
      }
    } catch (e) {
      debugPrint('Download error: $e');
    } finally {
      final prog = Map<String, double>.from(state.downloadProgress);
      prog.remove(image.id);
      state = state.copyWith(downloadProgress: prog);
    }
  }

  // Delete downloaded image
  Future<void> deleteDownload(String imageId) async {
    try {
      final success = await _apiService.deleteImageDownload(imageId);
      if (success) {
        await loadDownloadedImages();

        // Remove from selection if present
        final selected = state.selectedImages
            .where((i) => i.id != imageId)
            .toList();
        state = state.copyWith(selectedImages: selected);
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final pixabayApiServiceProvider = Provider<PixabayApiService>((ref) {
  return PixabayApiService();
});

final imagePickerProvider =
    StateNotifierProvider<ImagePickerNotifier, ImagePickerState>((ref) {
      final apiService = ref.watch(pixabayApiServiceProvider);
      return ImagePickerNotifier(apiService);
    });

// Convenience providers
final selectedImagesProvider = Provider<List<StockImage>>((ref) {
  return ref.watch(imagePickerProvider).selectedImages;
});

final downloadedImagesCountProvider = Provider<int>((ref) {
  return ref.watch(imagePickerProvider).downloadedImages.length;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import '../services/database_service.dart';
import '../services/file_scanner_service.dart';
import '../services/thumbnail_service.dart';

// ============ Images Provider ============

final imagesProvider = FutureProvider.autoDispose<List<MediaFile>>((ref) async {
  try {
    final db = DatabaseService.instance;
    final images = await db.getMediaFilesByType(MediaType.image);

    // Sort by date added (newest first)
    images.sort(
      (a, b) =>
          (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
    );

    return images;
  } catch (e) {
    throw Exception('Failed to load images: $e');
  }
});

// ============ Images by Folder Provider ============

final imagesByFolderProvider =
    FutureProvider.autoDispose<Map<String, List<MediaFile>>>((ref) async {
      try {
        final images = await ref.watch(imagesProvider.future);

        final Map<String, List<MediaFile>> folderMap = {};

        for (final image in images) {
          final folderPath = path.dirname(image.path);
          final folderName = path.basename(folderPath);

          if (!folderMap.containsKey(folderName)) {
            folderMap[folderName] = [];
          }
          folderMap[folderName]!.add(image);
        }

        return folderMap;
      } catch (e) {
        throw Exception('Failed to group images by folder: $e');
      }
    });

// ============ Images by Date Provider ============

final imagesByDateProvider =
    FutureProvider.autoDispose<Map<String, List<MediaFile>>>((ref) async {
      try {
        final images = await ref.watch(imagesProvider.future);

        final Map<String, List<MediaFile>> dateMap = {};

        for (final image in images) {
          final dateKey = _formatDateKey(image.dateAdded ?? DateTime(0));

          if (!dateMap.containsKey(dateKey)) {
            dateMap[dateKey] = [];
          }
          dateMap[dateKey]!.add(image);
        }

        return dateMap;
      } catch (e) {
        throw Exception('Failed to group images by date: $e');
      }
    });

String _formatDateKey(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final imageDate = DateTime(date.year, date.month, date.day);

  if (imageDate == today) {
    return 'Today';
  } else if (imageDate == yesterday) {
    return 'Yesterday';
  } else if (now.difference(imageDate).inDays < 7) {
    return 'This Week';
  } else if (now.difference(imageDate).inDays < 30) {
    return 'This Month';
  } else {
    return '${_getMonthName(date.month)} ${date.year}';
  }
}

String _getMonthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

// ============ Favorite Images Provider ============

final favoriteImagesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final db = DatabaseService.instance;
    final favorites = await db.getFavoriteMediaFiles();
    return favorites.where((f) => f.type == MediaType.image).toList();
  } catch (e) {
    throw Exception('Failed to load favorite images: $e');
  }
});

// ============ Recent Images Provider ============

final recentImagesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final images = await ref.watch(imagesProvider.future);

    // Get last 20 images
    return images.take(20).toList();
  } catch (e) {
    throw Exception('Failed to load recent images: $e');
  }
});

// ============ Image Search Provider ============

final imageSearchQueryProvider = Provider<String>((ref) => '');

final filteredImagesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final images = await ref.watch(imagesProvider.future);
    final query = ref.watch(imageSearchQueryProvider).toLowerCase();

    if (query.isEmpty) {
      return images;
    }

    return images.where((image) {
      final name = path.basename(image.path).toLowerCase();
      final folder = path.dirname(image.path).toLowerCase();
      return name.contains(query) || folder.contains(query);
    }).toList();
  } catch (e) {
    throw Exception('Failed to filter images: $e');
  }
});

// ============ Image Stats Provider ============

final imageStatsProvider = FutureProvider.autoDispose<ImageStats>((ref) async {
  try {
    final images = await ref.watch(imagesProvider.future);

    int totalSize = 0;
    int jpgCount = 0;
    int pngCount = 0;
    int gifCount = 0;
    int webpCount = 0;
    int otherCount = 0;

    for (final image in images) {
      totalSize += image.size;

      final ext = path.extension(image.path).toLowerCase();
      switch (ext) {
        case '.jpg':
        case '.jpeg':
          jpgCount++;
          break;
        case '.png':
          pngCount++;
          break;
        case '.gif':
          gifCount++;
          break;
        case '.webp':
          webpCount++;
          break;
        default:
          otherCount++;
      }
    }

    return ImageStats(
      totalCount: images.length,
      totalSize: totalSize,
      jpgCount: jpgCount,
      pngCount: pngCount,
      gifCount: gifCount,
      webpCount: webpCount,
      otherCount: otherCount,
    );
  } catch (e) {
    throw Exception('Failed to calculate image stats: $e');
  }
});

class ImageStats {
  final int totalCount;
  final int totalSize;
  final int jpgCount;
  final int pngCount;
  final int gifCount;
  final int webpCount;
  final int otherCount;

  ImageStats({
    required this.totalCount,
    required this.totalSize,
    required this.jpgCount,
    required this.pngCount,
    required this.gifCount,
    required this.webpCount,
    required this.otherCount,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(totalSize / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

// ============ Image Notifier (for mutations) ============

class ImagesNotifier extends Notifier<AsyncValue<List<MediaFile>>> {
  final _db = DatabaseService.instance;

  @override
  AsyncValue<List<MediaFile>> build() {
    _loadImages();
    return const AsyncValue.loading();
  }

  Future<void> _loadImages() async {
    state = const AsyncValue.loading();
    try {
      final images = await _db.getMediaFilesByType(MediaType.image);
      images.sort(
        (a, b) =>
            (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
      );
      state = AsyncValue.data(images);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await _loadImages();
  }

  Future<void> scanForImages() async {
    try {
      state = const AsyncValue.loading();

      final scanner = FileScannerService.instance;
      final locations = await scanner.getAvailableStorageLocations();

      for (final location in locations) {
        await scanner.scanDirectory(location.path);
      }

      await _loadImages();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final stat = await file.stat();
      final extension = path.extension(filePath).toLowerCase();

      if (!_isImageExtension(extension)) {
        throw Exception('Not an image file');
      }

      // Generate thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath = await ThumbnailService.instance.generateImageThumbnail(
          filePath,
        );
      } catch (e) {
        // Continue without thumbnail
      }

      // Get image dimensions
      int? width;
      int? height;
      try {
        final dimensions = await _getImageDimensions(filePath);
        width = dimensions['width'];
        height = dimensions['height'];
      } catch (e) {
        // Continue without dimensions
      }

      final mediaFile = MediaFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: filePath,
        name: path.basename(filePath),
        type: MediaType.image,
        size: stat.size,
        dateAdded: DateTime.now(),
        dateModified: stat.modified,
        thumbnailPath: thumbnailPath,
        width: width,
        height: height,
      );

      await _db.insertMediaFile(mediaFile);
      await _loadImages();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteImage(String id) async {
    try {
      await _db.deleteMediaFile(id);
      await _loadImages();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleFavorite(MediaFile image) async {
    try {
      final updated = image.copyWith(isFavorite: !image.isFavorite);
      await _db.updateMediaFile(updated);
      await _loadImages();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateImage(MediaFile image) async {
    try {
      await _db.updateMediaFile(image);
      await _loadImages();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMultipleImages(List<String> ids) async {
    try {
      for (final id in ids) {
        await _db.deleteMediaFile(id);
      }
      await _loadImages();
    } catch (e) {
      rethrow;
    }
  }

  bool _isImageExtension(String ext) {
    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
      '.heif',
    ];
    return imageExtensions.contains(ext.toLowerCase());
  }

  Future<Map<String, int>> _getImageDimensions(String filePath) async {
    try {
      // This is a placeholder - you would use image package or native code
      // to get actual dimensions
      return {'width': 0, 'height': 0};
    } catch (e) {
      return {'width': 0, 'height': 0};
    }
  }
}

final imagesNotifierProvider =
    NotifierProvider<ImagesNotifier, AsyncValue<List<MediaFile>>>(() {
      return ImagesNotifier();
    });

// ============ Single Image Provider ============

final singleImageProvider = FutureProvider.autoDispose
    .family<MediaFile?, String>((ref, id) async {
      try {
        final db = DatabaseService.instance;
        return await db.getMediaFileById(id);
      } catch (e) {
        return null;
      }
    });

// ============ Image Folder Provider ============

final imageFoldersProvider = FutureProvider.autoDispose<List<ImageFolder>>((
  ref,
) async {
  try {
    final images = await ref.watch(imagesProvider.future);

    final Map<String, ImageFolder> folderMap = {};

    for (final image in images) {
      final folderPath = path.dirname(image.path);
      final folderName = path.basename(folderPath);

      if (!folderMap.containsKey(folderPath)) {
        folderMap[folderPath] = ImageFolder(
          path: folderPath,
          name: folderName,
          images: [],
          thumbnailPath: image.thumbnailPath ?? image.path,
        );
      }
      folderMap[folderPath]!.images.add(image);
    }

    final folders = folderMap.values.toList();
    folders.sort((a, b) => b.images.length.compareTo(a.images.length));

    return folders;
  } catch (e) {
    throw Exception('Failed to get image folders: $e');
  }
});

class ImageFolder {
  final String path;
  final String name;
  final List<MediaFile> images;
  final String thumbnailPath;

  ImageFolder({
    required this.path,
    required this.name,
    required this.images,
    required this.thumbnailPath,
  });

  int get imageCount => images.length;

  int get totalSize => images.fold(0, (sum, img) => sum + img.size);

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(totalSize / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

// ============ Selected Images Provider (for multi-select) ============

final selectedImagesProvider =
    NotifierProvider<SelectedImagesNotifier, Set<String>>(() {
      return SelectedImagesNotifier();
    });

class SelectedImagesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void select(String id) {
    state = {...state, id};
  }

  void deselect(String id) {
    state = {...state}..remove(id);
  }

  void selectAll(List<String> ids) {
    state = {...state, ...ids};
  }

  void deselectAll() {
    state = {};
  }

  void clear() {
    state = {};
  }

  bool isSelected(String id) => state.contains(id);

  int get count => state.length;
}

// ============ Image Sort Provider ============

enum ImageSortType {
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  sizeSmallest,
  sizeLargest,
}

final imageSortTypeProvider = Provider<ImageSortType>((ref) {
  return ImageSortType.dateNewest;
});

final sortedImagesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final images = await ref.watch(imagesProvider.future);
    final sortType = ref.watch(imageSortTypeProvider);

    final sortedImages = List<MediaFile>.from(images);

    switch (sortType) {
      case ImageSortType.dateNewest:
        sortedImages.sort((a, b) => (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)));
        break;
      case ImageSortType.dateOldest:
        sortedImages.sort((a, b) => (a.dateAdded ?? DateTime(0)).compareTo(b.dateAdded ?? DateTime(0)));
        break;
      case ImageSortType.nameAZ:
        sortedImages.sort(
          (a, b) => path
              .basename(a.path)
              .toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase()),
        );
        break;
      case ImageSortType.nameZA:
        sortedImages.sort(
          (a, b) => path
              .basename(b.path)
              .toLowerCase()
              .compareTo(path.basename(a.path).toLowerCase()),
        );
        break;
      case ImageSortType.sizeSmallest:
        sortedImages.sort((a, b) => a.size.compareTo(b.size));
        break;
      case ImageSortType.sizeLargest:
        sortedImages.sort((a, b) => b.size.compareTo(a.size));
        break;
    }

    return sortedImages;
  } catch (e) {
    throw Exception('Failed to sort images: $e');
  }
});

// ============ Image View Mode Provider ============

enum ImageViewMode { grid, list, folder, date }

final imageViewModeProvider = Provider<ImageViewMode>((ref) {
  return ImageViewMode.grid;
});

// ============ Image Grid Size Provider ============

final imageGridSizeProvider = Provider<int>((ref) {
  return 3; // Default 3 columns
});

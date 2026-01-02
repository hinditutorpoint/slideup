import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import '../services/database_service.dart';

// ============ Sort Type ============

enum FavoriteSortType { date, name, size, type }

class FavoriteSortTypeNotifier extends Notifier<FavoriteSortType> {
  @override
  FavoriteSortType build() {
    return FavoriteSortType.date;
  }

  void setSortType(FavoriteSortType sortType) {
    state = sortType;
  }
}

final favoriteSortTypeProvider =
    NotifierProvider<FavoriteSortTypeNotifier, FavoriteSortType>(() {
      return FavoriteSortTypeNotifier();
    });

// ============ All Favorites Provider ============

final allFavoritesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final db = DatabaseService.instance;
    final favorites = await db.getFavoriteMediaFiles();
    final sortType = ref.watch(favoriteSortTypeProvider);

    return _sortFavorites(favorites, sortType);
  } catch (e) {
    throw Exception('Failed to load favorites: $e');
  }
});

// ============ Type-Specific Favorites Providers ============

final favoriteVideosProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    return favorites.where((f) => f.type == MediaType.video).toList();
  } catch (e) {
    throw Exception('Failed to load favorite videos: $e');
  }
});

final favoriteAudiosProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    return favorites.where((f) => f.type == MediaType.audio).toList();
  } catch (e) {
    throw Exception('Failed to load favorite audio: $e');
  }
});

final favoriteImagesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    return favorites.where((f) => f.type == MediaType.image).toList();
  } catch (e) {
    throw Exception('Failed to load favorite images: $e');
  }
});

final favoriteDocumentsProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    return favorites.where((f) => f.type == MediaType.document).toList();
  } catch (e) {
    throw Exception('Failed to load favorite documents: $e');
  }
});

// ============ Favorites Stats Provider ============

final favoritesStatsProvider = FutureProvider.autoDispose<FavoritesStats>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);

    int totalSize = 0;
    int videoCount = 0;
    int audioCount = 0;
    int imageCount = 0;
    int documentCount = 0;

    for (final file in favorites) {
      totalSize += file.size;

      switch (file.type) {
        case MediaType.video:
          videoCount++;
          break;
        case MediaType.audio:
          audioCount++;
          break;
        case MediaType.image:
          imageCount++;
          break;
        case MediaType.document:
          documentCount++;
          break;
        default:
          break;
      }
    }

    return FavoritesStats(
      totalCount: favorites.length,
      totalSize: totalSize,
      videoCount: videoCount,
      audioCount: audioCount,
      imageCount: imageCount,
      documentCount: documentCount,
    );
  } catch (e) {
    throw Exception('Failed to calculate favorites stats: $e');
  }
});

class FavoritesStats {
  final int totalCount;
  final int totalSize;
  final int videoCount;
  final int audioCount;
  final int imageCount;
  final int documentCount;

  FavoritesStats({
    required this.totalCount,
    required this.totalSize,
    required this.videoCount,
    required this.audioCount,
    required this.imageCount,
    required this.documentCount,
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

// ============ Favorites Notifier (for mutations) ============

class FavoritesNotifier extends Notifier<AsyncValue<List<MediaFile>>> {
  final _db = DatabaseService.instance;

  @override
  AsyncValue<List<MediaFile>> build() {
    _loadFavorites();
    return const AsyncValue.loading();
  }

  Future<void> _loadFavorites() async {
    state = const AsyncValue.loading();
    try {
      final favorites = await _db.getFavoriteMediaFiles();
      favorites.sort(
        (a, b) =>
            (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
      );
      state = AsyncValue.data(favorites);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await _loadFavorites();
  }

  Future<void> addToFavorites(String mediaId) async {
    try {
      final file = await _db.getMediaFileById(mediaId);
      if (file == null) {
        throw Exception('Media file not found');
      }

      final updated = file.copyWith(isFavorite: true);
      await _db.updateMediaFile(updated);
      await _loadFavorites();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromFavorites(String mediaId) async {
    try {
      final file = await _db.getMediaFileById(mediaId);
      if (file == null) {
        throw Exception('Media file not found');
      }

      final updated = file.copyWith(isFavorite: false);
      await _db.updateMediaFile(updated);
      await _loadFavorites();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleFavorite(String mediaId) async {
    try {
      final file = await _db.getMediaFileById(mediaId);
      if (file == null) {
        throw Exception('Media file not found');
      }

      final updated = file.copyWith(isFavorite: !file.isFavorite);
      await _db.updateMediaFile(updated);
      await _loadFavorites();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMultipleToFavorites(List<String> mediaIds) async {
    try {
      for (final id in mediaIds) {
        try {
          final file = await _db.getMediaFileById(id);
          if (file != null) {
            final updated = file.copyWith(isFavorite: true);
            await _db.updateMediaFile(updated);
          }
        } catch (e) {
          // Continue with other files
        }
      }
      await _loadFavorites();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMultipleFromFavorites(List<String> mediaIds) async {
    try {
      for (final id in mediaIds) {
        try {
          final file = await _db.getMediaFileById(id);
          if (file != null) {
            final updated = file.copyWith(isFavorite: false);
            await _db.updateMediaFile(updated);
          }
        } catch (e) {
          // Continue with other files
        }
      }
      await _loadFavorites();
    } catch (e) {
      rethrow;
    }
  }

  bool isFavorite(String mediaId) {
    return state.maybeWhen(
      data: (favorites) => favorites.any((f) => f.id == mediaId),
      orElse: () => false,
    );
  }
}

final favoritesNotifierProvider =
    NotifierProvider<FavoritesNotifier, AsyncValue<List<MediaFile>>>(() {
      return FavoritesNotifier();
    });

// ============ Is Favorite Provider ============

final isFavoriteProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  mediaId,
) async {
  try {
    final db = DatabaseService.instance;
    final file = await db.getMediaFileById(mediaId);
    return file?.isFavorite ?? false;
  } catch (e) {
    return false;
  }
});

// ============ Recent Favorites Provider ============

final recentFavoritesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    // Return last 10 favorites
    return favorites.take(10).toList();
  } catch (e) {
    throw Exception('Failed to load recent favorites: $e');
  }
});

// ============ Search Favorites Provider ============

final favoriteSearchQueryProvider = Provider<String>((ref) => '');

final filteredFavoritesProvider = FutureProvider.autoDispose<List<MediaFile>>((
  ref,
) async {
  try {
    final favorites = await ref.watch(allFavoritesProvider.future);
    final query = ref.watch(favoriteSearchQueryProvider).toLowerCase();

    if (query.isEmpty) {
      return favorites;
    }

    return favorites.where((file) {
      final name = path.basename(file.path).toLowerCase();
      final folder = path.dirname(file.path).toLowerCase();
      return name.contains(query) || folder.contains(query);
    }).toList();
  } catch (e) {
    throw Exception('Failed to filter favorites: $e');
  }
});

// ============ Helper Functions ============

List<MediaFile> _sortFavorites(
  List<MediaFile> favorites,
  FavoriteSortType sortType,
) {
  final sorted = List<MediaFile>.from(favorites);

  switch (sortType) {
    case FavoriteSortType.date:
      sorted.sort(
        (a, b) =>
            (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
      );
      break;
    case FavoriteSortType.name:
      sorted.sort(
        (a, b) => path
            .basename(a.path)
            .toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase()),
      );
      break;
    case FavoriteSortType.size:
      sorted.sort((a, b) => b.size.compareTo(a.size));
      break;
    case FavoriteSortType.type:
      sorted.sort((a, b) => a.type.index.compareTo(b.type.index));
      break;
  }

  return sorted;
}

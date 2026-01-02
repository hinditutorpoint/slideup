import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repositories/video_repository.dart';
import '../models/video_file.dart';
import '../models/video_metadata.dart';
import '../models/thumbnail_file.dart';
import 'video_providers.dart';
import '../../../../models/media_file.dart';
import '../../../../services/database_service.dart';

enum MetadataViewMode { grid, list }

// View mode for metadata screen
final metadataViewModeProvider = StateProvider<MetadataViewMode>(
  (ref) => MetadataViewMode.list,
);

// Filter for video files
enum VideoFileFilter { all, original, derivative }

final videoFileFilterProvider = StateProvider<VideoFileFilter>(
  (ref) => VideoFileFilter.all,
);

// Metadata state
class VideoMetadataState {
  final bool isLoading;
  final VideoMetadata? metadata;
  final String? error;
  final Set<String> likedFiles;
  final Set<String> favoriteFiles;
  final Set<String> likedThumbnails;

  const VideoMetadataState({
    this.isLoading = false,
    this.metadata,
    this.error,
    this.likedFiles = const {},
    this.favoriteFiles = const {},
    this.likedThumbnails = const {},
  });

  /// Get all video files
  List<VideoFile> get allVideoFiles => metadata?.videoFiles ?? [];

  /// Get all thumbnails
  List<ThumbnailFile> get allThumbnails => metadata?.thumbnails ?? [];

  /// Get filtered video files
  List<VideoFile> getFilteredVideoFiles(VideoFileFilter filter) {
    final files = allVideoFiles;
    switch (filter) {
      case VideoFileFilter.all:
        return files;
      case VideoFileFilter.original:
        return files.where((f) => f.isOriginal).toList();
      case VideoFileFilter.derivative:
        return files.where((f) => f.isDerivative).toList();
    }
  }

  /// Check if file is liked
  bool isFileLiked(String fileName) => likedFiles.contains(fileName);

  /// Check if file is favorite
  bool isFileFavorite(String fileName) => favoriteFiles.contains(fileName);

  /// Check if thumbnail is liked
  bool isThumbnailLiked(String fileName) => likedThumbnails.contains(fileName);

  bool isThumbnailFavorite(String fileName) => favoriteFiles.contains(fileName);

  /// Get video files count
  int get videoFilesCount => allVideoFiles.length;

  /// Get thumbnails count
  int get thumbnailsCount => allThumbnails.length;

  /// Get best quality video file
  VideoFile? get bestQualityFile {
    if (allVideoFiles.isEmpty) return null;
    return allVideoFiles.first; // Already sorted by quality
  }

  VideoMetadataState copyWith({
    bool? isLoading,
    VideoMetadata? metadata,
    String? error,
    Set<String>? likedFiles,
    Set<String>? favoriteFiles,
    Set<String>? likedThumbnails,
  }) {
    return VideoMetadataState(
      isLoading: isLoading ?? this.isLoading,
      metadata: metadata ?? this.metadata,
      error: error,
      likedFiles: likedFiles ?? this.likedFiles,
      favoriteFiles: favoriteFiles ?? this.favoriteFiles,
      likedThumbnails: likedThumbnails ?? this.likedThumbnails,
    );
  }
}

// Metadata notifier
class VideoMetadataNotifier extends StateNotifier<VideoMetadataState> {
  final VideoRepository _repository;
  final String identifier;

  VideoMetadataNotifier(this._repository, this.identifier)
    : super(const VideoMetadataState()) {
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final metadataMap = await _repository.getVideoMetadata(identifier);
      final metadata = VideoMetadata.fromJson(metadataMap);

      // Load persistent favorite data from database
      final favoriteFiles = await _loadFavoriteFilesFromDatabase();
      final favoriteThumbnails = await _loadFavoriteThumbnailsFromDatabase();

      state = state.copyWith(
        isLoading: false,
        metadata: metadata,
        favoriteFiles: favoriteFiles,
        likedThumbnails: favoriteThumbnails,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  void toggleFileLike(String fileName) {
    final newLikedFiles = Set<String>.from(state.likedFiles);
    if (newLikedFiles.contains(fileName)) {
      newLikedFiles.remove(fileName);
    } else {
      newLikedFiles.add(fileName);
    }
    state = state.copyWith(likedFiles: newLikedFiles);
  }

  void toggleThumbnailLike(String fileName) {
    final newLikedThumbnails = Set<String>.from(state.likedThumbnails);
    if (newLikedThumbnails.contains(fileName)) {
      newLikedThumbnails.remove(fileName);
    } else {
      newLikedThumbnails.add(fileName);
    }
    state = state.copyWith(likedThumbnails: newLikedThumbnails);
  }

  Future<void> toggleThumbnailFavorite(Map<String, dynamic> thumbnail) async {
    try {
      final fileName =
          thumbnail['fileName'] as String? ??
          thumbnail['name'] as String? ??
          'Unknown';
      final isCurrentlyFavorite = state.favoriteFiles.contains(fileName);
      final newFavoriteStatus = !isCurrentlyFavorite;

      // Update in-memory state immediately for responsiveness
      final newFavoriteFiles = Set<String>.from(state.favoriteFiles);
      if (newFavoriteStatus) {
        newFavoriteFiles.add(fileName);
      } else {
        newFavoriteFiles.remove(fileName);
      }
      state = state.copyWith(favoriteFiles: newFavoriteFiles);

      // Convert thumbnail to MediaFile
      final mediaFile = _createMediaFileFromThumbnail(
        thumbnail,
        newFavoriteStatus,
      );

      // Check if exists in database and update/insert
      await _updateOrInsertFavorite(mediaFile, newFavoriteStatus);
    } catch (e) {
      // Revert in-memory state on error
      final fileName =
          thumbnail['fileName'] as String? ??
          thumbnail['name'] as String? ??
          'Unknown';
      final newFavoriteFiles = Set<String>.from(state.favoriteFiles);
      if (state.favoriteFiles.contains(fileName)) {
        newFavoriteFiles.remove(fileName);
      } else {
        newFavoriteFiles.add(fileName);
      }
      state = state.copyWith(favoriteFiles: newFavoriteFiles);
      rethrow;
    }
  }

  Future<void> toggleFileFavorite(Map<String, dynamic> file) async {
    try {
      final fileName =
          file['fileName'] as String? ?? file['name'] as String? ?? 'Unknown';
      final isCurrentlyFavorite = state.favoriteFiles.contains(fileName);
      final newFavoriteStatus = !isCurrentlyFavorite;

      // Update in-memory state immediately for responsiveness
      final newFavoriteFiles = Set<String>.from(state.favoriteFiles);
      if (newFavoriteStatus) {
        newFavoriteFiles.add(fileName);
      } else {
        newFavoriteFiles.remove(fileName);
      }
      state = state.copyWith(favoriteFiles: newFavoriteFiles);

      // Convert video file to MediaFile
      final mediaFile = _createMediaFileFromVideoFile(file, newFavoriteStatus);

      // Check if exists in database and update/insert
      await _updateOrInsertFavorite(mediaFile, newFavoriteStatus);
    } catch (e) {
      // Revert in-memory state on error
      final fileName =
          file['fileName'] as String? ?? file['name'] as String? ?? 'Unknown';
      final newFavoriteFiles = Set<String>.from(state.favoriteFiles);
      if (state.favoriteFiles.contains(fileName)) {
        newFavoriteFiles.remove(fileName);
      } else {
        newFavoriteFiles.add(fileName);
      }
      state = state.copyWith(favoriteFiles: newFavoriteFiles);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadMetadata();
  }

  Future<Set<String>> _loadFavoriteFilesFromDatabase() async {
    try {
      final dbService = DatabaseService.instance;
      final favoriteMediaFiles = await dbService.getFavoriteMediaFiles();

      // For SHA1-based IDs, we need to check if the file path contains the identifier
      // since SHA1 is unique and doesn't include the identifier prefix
      final filteredFavorites = favoriteMediaFiles
          .where(
            (file) =>
                file.path.contains('/$identifier/') &&
                file.type == MediaType.video,
          )
          .map((file) => file.name)
          .toSet();

      return filteredFavorites;
    } catch (e) {
      // If there's an error loading from database, return empty set
      return {};
    }
  }

  Future<Set<String>> _loadFavoriteThumbnailsFromDatabase() async {
    try {
      final dbService = DatabaseService.instance;
      final favoriteMediaFiles = await dbService.getFavoriteMediaFiles();

      // For SHA1-based IDs, we need to check if the file path contains the identifier
      // since SHA1 is unique and doesn't include the identifier prefix
      final filteredFavorites = favoriteMediaFiles
          .where(
            (file) =>
                file.path.contains('/$identifier/') &&
                file.type == MediaType.image,
          )
          .map((file) => file.name)
          .toSet();

      return filteredFavorites;
    } catch (e) {
      // If there's an error loading from database, return empty set
      return {};
    }
  }

  MediaFile _createMediaFileFromThumbnail(
    Map<String, dynamic> thumbnail,
    bool isFavorite,
  ) {
    final fileName =
        thumbnail['fileName'] as String? ??
        thumbnail['name'] as String? ??
        'Unknown';
    final sha1 = thumbnail['sha1'] as String? ?? '';
    final url = 'https://archive.org/download/$identifier/$fileName';
    final thumb = 'https://archive.org/services/img/$identifier';

    return MediaFile(
      id: sha1.isNotEmpty ? sha1 : '${identifier}_$fileName',
      name: fileName,
      path: url,
      type: MediaType.image,
      size: thumbnail['size'] as int? ?? 0,
      dateModified: DateTime.now(),
      dateAdded: DateTime.now(),
      mimeType: 'image/${thumbnail['format'] ?? 'jpeg'}',
      thumbnailPath: thumb,
      isFavorite: isFavorite,
    );
  }

  MediaFile _createMediaFileFromVideoFile(
    Map<String, dynamic> file,
    bool isFavorite,
  ) {
    final fileName =
        file['fileName'] as String? ?? file['name'] as String? ?? 'Unknown';
    final sha1 = file['sha1'] as String? ?? '';
    final url = 'https://archive.org/download/$identifier/$fileName';
    final thumb = 'https://archive.org/services/img/$identifier';

    return MediaFile(
      id: sha1.isNotEmpty ? sha1 : '${identifier}_$fileName',
      name: fileName,
      path: url,
      type: MediaType.video,
      thumbnailPath: thumb,
      size: file['size'] as int? ?? 0,
      dateModified: DateTime.now(),
      dateAdded: DateTime.now(),
      mimeType: 'video/${file['format'] ?? 'mp4'}',
      duration: file['length'] != null
          ? (double.tryParse(file['length'].toString()) ?? 0).toInt() * 1000
          : null,
      height: file['height'] != null
          ? int.tryParse(file['height'].toString())
          : null,
      width: file['width'] != null
          ? int.tryParse(file['width'].toString())
          : null,
      isFavorite: isFavorite,
    );
  }

  Future<void> _updateOrInsertFavorite(
    MediaFile mediaFile,
    bool isFavorite,
  ) async {
    final dbService = DatabaseService.instance;

    // Check if the media file already exists in the database
    final existingFile = await dbService.getMediaFileById(mediaFile.id);

    if (existingFile != null) {
      // Update existing file with new favorite status
      final updatedFile = existingFile.copyWith(isFavorite: isFavorite);
      await dbService.updateMediaFile(updatedFile);
    } else {
      // Insert new file with the favorite status
      await dbService.insertMediaFile(mediaFile);
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('no internet') || errorStr.contains('socket')) {
      return 'No internet connection. Please check your network.';
    } else if (errorStr.contains('timed out') || errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('server error') || errorStr.contains('500')) {
      return 'Server error. Please try again later.';
    } else if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Video not found.';
    }
    return 'Failed to load video details. Please try again.';
  }
}

// Provider family for metadata by identifier
final videoMetadataNotifierProvider =
    StateNotifierProvider.family<
      VideoMetadataNotifier,
      VideoMetadataState,
      String
    >((ref, identifier) {
      return VideoMetadataNotifier(
        ref.watch(videoRepositoryProvider),
        identifier,
      );
    });

// Convenient provider for filtered files
final filteredVideoFilesProvider = Provider.family<List<VideoFile>, String>((
  ref,
  identifier,
) {
  final state = ref.watch(videoMetadataNotifierProvider(identifier));
  final filter = ref.watch(videoFileFilterProvider);
  return state.getFilteredVideoFiles(filter);
});

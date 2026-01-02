import 'package:flutter_riverpod/legacy.dart';
import '../models/pdf_file.dart';
import '../models/pdf_metadata.dart';
import '../../video_search/models/thumbnail_file.dart';
import '../repositories/pdf_repository.dart';
import 'pdf_providers.dart';

enum PdfViewMode { grid, list }

final pdfMetaViewModeProvider = StateProvider<PdfViewMode>(
  (ref) => PdfViewMode.list,
);

enum PdfFileFilter { all, pdf, epub, other }

final pdfFileFilterProvider = StateProvider<PdfFileFilter>(
  (ref) => PdfFileFilter.all,
);

class PdfMetadataState {
  final bool isLoading;
  final PdfMetadata? metadata;
  final String? error;
  final Set<String> likedFiles;

  const PdfMetadataState({
    this.isLoading = false,
    this.metadata,
    this.error,
    this.likedFiles = const {},
  });

  List<PdfFile> get allFiles => metadata?.documentFiles ?? [];
  List<ThumbnailFile> get allThumbnails => metadata?.thumbnails ?? [];
  int get filesCount => allFiles.length;
  int get thumbnailsCount => allThumbnails.length;

  List<PdfFile> getFilteredFiles(PdfFileFilter filter) {
    switch (filter) {
      case PdfFileFilter.all:
        return allFiles;
      case PdfFileFilter.pdf:
        return allFiles.where((f) => f.isPdf).toList();
      case PdfFileFilter.epub:
        return allFiles.where((f) => f.isEpub).toList();
      case PdfFileFilter.other:
        return allFiles.where((f) => !f.isPdf && !f.isEpub).toList();
    }
  }

  bool isFileLiked(String fileName) => likedFiles.contains(fileName);

  PdfMetadataState copyWith({
    bool? isLoading,
    PdfMetadata? metadata,
    String? error,
    Set<String>? likedFiles,
  }) {
    return PdfMetadataState(
      isLoading: isLoading ?? this.isLoading,
      metadata: metadata ?? this.metadata,
      error: error,
      likedFiles: likedFiles ?? this.likedFiles,
    );
  }
}

class PdfMetadataNotifier extends StateNotifier<PdfMetadataState> {
  final PdfRepository _repository;
  final String identifier;

  PdfMetadataNotifier(this._repository, this.identifier)
    : super(const PdfMetadataState()) {
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final metadata = await _repository.getPdfMetadata(identifier);
      if (mounted) state = state.copyWith(isLoading: false, metadata: metadata);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void toggleFileLike(String fileName) {
    final newLiked = Set<String>.from(state.likedFiles);
    newLiked.contains(fileName)
        ? newLiked.remove(fileName)
        : newLiked.add(fileName);
    state = state.copyWith(likedFiles: newLiked);
  }

  Future<void> refresh() async => _loadMetadata();
}

final pdfMetadataNotifierProvider =
    StateNotifierProvider.family<PdfMetadataNotifier, PdfMetadataState, String>(
      (ref, identifier) {
        return PdfMetadataNotifier(
          ref.watch(pdfRepositoryProvider),
          identifier,
        );
      },
    );

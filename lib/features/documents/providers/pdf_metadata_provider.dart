import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/pdf_file.dart';
import '../models/pdf_metadata.dart';
import '../../video_search/models/thumbnail_file.dart';
import '../repositories/pdf_repository.dart';
import 'pdf_providers.dart';

import '../../../core/constants/languages.dart';

import '../../../services/settings_service.dart';

enum PdfViewMode { grid, list }

class PdfMetaViewModeNotifier extends Notifier<PdfViewMode> {
  @override
  PdfViewMode build() {
    final isGrid = SettingsService.instance.isGridView;
    return isGrid ? PdfViewMode.grid : PdfViewMode.list;
  }

  void toggle() {
    final newMode =
        state == PdfViewMode.grid ? PdfViewMode.list : PdfViewMode.grid;
    state = newMode;
    SettingsService.instance.setIsGridView(newMode == PdfViewMode.grid);
  }

  void setMode(PdfViewMode mode) {
    state = mode;
    SettingsService.instance.setIsGridView(mode == PdfViewMode.grid);
  }
}

final pdfMetaViewModeProvider =
    NotifierProvider<PdfMetaViewModeNotifier, PdfViewMode>(
      PdfMetaViewModeNotifier.new,
    );

enum PdfFileFilter { all, pdf, epub, other }

final pdfFileFilterProvider = StateProvider<PdfFileFilter>(
  (ref) => PdfFileFilter.all,
);

final pdfFileLanguageFilterProvider = StateProvider<Language>(
  (ref) => AppLanguages.all,
);

class PdfMetadataState {
  final bool isLoading;
  final PdfMetadata? metadata;
  final String? error;
  final Set<String> likedFiles;
  final Set<String> likedThumbnails;

  const PdfMetadataState({
    this.isLoading = false,
    this.metadata,
    this.error,
    this.likedFiles = const {},
    this.likedThumbnails = const {},
  });

  List<PdfFile> get allFiles => metadata?.documentFiles ?? [];
  List<ThumbnailFile> get allThumbnails => metadata?.thumbnails ?? [];
  int get filesCount => allFiles.length;
  int get thumbnailsCount => allThumbnails.length;

  List<PdfFile> getFilteredFiles({
    PdfFileFilter formatFilter = PdfFileFilter.all,
    Language languageFilter = AppLanguages.all,
  }) {
    var files = allFiles;

    // Filter by file type
    switch (formatFilter) {
      case PdfFileFilter.all:
        break;
      case PdfFileFilter.pdf:
        files = files.where((f) => f.isPdf).toList();
        break;
      case PdfFileFilter.epub:
        files = files.where((f) => f.isEpub).toList();
        break;
      case PdfFileFilter.other:
        files = files.where((f) => !f.isPdf && !f.isEpub).toList();
        break;
    }

    // Filter by language
    if (languageFilter.code.isNotEmpty) {
      files = files
          .where((f) => f.matchesLanguage(languageFilter, metadata?.language))
          .toList();
    }

    return files;
  }

  /// Extracts all distinct languages detected across files or item metadata
  List<Language> getDetectedLanguages() {
    final result = <Language>{};

    for (final lang in AppLanguages.supportedLanguages) {
      if (lang.code.isEmpty) continue;
      final hasMatchingFile = allFiles.any(
        (f) => f.matchesLanguage(lang, metadata?.language),
      );
      if (hasMatchingFile) {
        result.add(lang);
      }
    }

    return result.toList();
  }

  bool isFileLiked(String fileName) => likedFiles.contains(fileName);
  bool isThumbnailLiked(String thumbName) => likedThumbnails.contains(thumbName);

  PdfMetadataState copyWith({
    bool? isLoading,
    PdfMetadata? metadata,
    String? error,
    Set<String>? likedFiles,
    Set<String>? likedThumbnails,
  }) {
    return PdfMetadataState(
      isLoading: isLoading ?? this.isLoading,
      metadata: metadata ?? this.metadata,
      error: error,
      likedFiles: likedFiles ?? this.likedFiles,
      likedThumbnails: likedThumbnails ?? this.likedThumbnails,
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

  void toggleThumbnailLike(String thumbName) {
    final newLiked = Set<String>.from(state.likedThumbnails);
    newLiked.contains(thumbName)
        ? newLiked.remove(thumbName)
        : newLiked.add(thumbName);
    state = state.copyWith(likedThumbnails: newLiked);
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

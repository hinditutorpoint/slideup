import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../services/file_operations_service.dart';
import '../services/settings_service.dart';
import '../services/search_service.dart';

class FileBrowserState {
  final Directory? currentDirectory;
  final List<FileSystemEntity> entities;
  final List<FileSystemEntity> selectedEntities;
  final bool isLoading;
  final bool isGridView;
  final bool isSelectionMode;
  final bool showHiddenFiles;
  final SortBy sortBy;
  final SortOrder sortOrder;
  final String? error;
  final List<MediaFile> searchResults;
  final bool isSearching;
  final String searchQuery;

  const FileBrowserState({
    this.currentDirectory,
    this.entities = const [],
    this.selectedEntities = const [],
    this.isLoading = false,
    this.isGridView = true,
    this.isSelectionMode = false,
    this.showHiddenFiles = false,
    this.sortBy = SortBy.name,
    this.sortOrder = SortOrder.ascending,
    this.error,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
  });

  FileBrowserState copyWith({
    Directory? currentDirectory,
    List<FileSystemEntity>? entities,
    List<FileSystemEntity>? selectedEntities,
    bool? isLoading,
    bool? isGridView,
    bool? isSelectionMode,
    bool? showHiddenFiles,
    SortBy? sortBy,
    SortOrder? sortOrder,
    String? error,
    List<MediaFile>? searchResults,
    bool? isSearching,
    String? searchQuery,
  }) {
    return FileBrowserState(
      currentDirectory: currentDirectory ?? this.currentDirectory,
      entities: entities ?? this.entities,
      selectedEntities: selectedEntities ?? this.selectedEntities,
      isLoading: isLoading ?? this.isLoading,
      isGridView: isGridView ?? this.isGridView,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      error: error,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FileBrowserNotifier extends Notifier<FileBrowserState> {
  @override
  FileBrowserState build() {
    _initialize();
    return const FileBrowserState();
  }

  Future<void> _initialize() async {
    // Load saved preferences
    final isGridView = await SettingsService.instance.getIsGridView();
    final showHiddenFiles = await SettingsService.instance.getShowHiddenFiles();
    final sortBy = await SettingsService.instance.getSortBy();
    final sortOrder = await SettingsService.instance.getSortOrder();
    final lastLocation = await SettingsService.instance.getLastLocation();

    state = state.copyWith(
      isGridView: isGridView,
      showHiddenFiles: showHiddenFiles,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );

    // Navigate to last location if available
    if (lastLocation != null) {
      await navigateToDirectory(Directory(lastLocation));
    }
  }

  Future<void> navigateToDirectory(Directory directory) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      if (!await directory.exists()) {
        throw Exception('Directory does not exist');
      }

      final entities = await directory.list().toList();
      final filteredEntities = _filterAndSortEntities(entities);

      state = state.copyWith(
        currentDirectory: directory,
        entities: filteredEntities,
        selectedEntities: [],
        isSelectionMode: false,
        isLoading: false,
      );

      // Save last location
      await SettingsService.instance.setLastLocation(directory.path);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load directory: $e',
      );
    }
  }

  List<FileSystemEntity> _filterAndSortEntities(
    List<FileSystemEntity> entities,
  ) {
    // Filter hidden files
    List<FileSystemEntity> filtered = entities;
    if (!state.showHiddenFiles) {
      filtered = entities.where((entity) {
        final name = entity.path.split('/').last;
        return !name.startsWith('.');
      }).toList();
    }

    // Sort entities
    filtered.sort((a, b) {
      // Directories first
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;

      final nameA = a.path.split('/').last;
      final nameB = b.path.split('/').last;

      int comparison = 0;
      switch (state.sortBy) {
        case SortBy.name:
          comparison = nameA.toLowerCase().compareTo(nameB.toLowerCase());
          break;
        case SortBy.size:
          if (a is File && b is File) {
            final sizeA = a.lengthSync();
            final sizeB = b.lengthSync();
            comparison = sizeA.compareTo(sizeB);
          }
          break;
        case SortBy.date:
          final dateA = a.statSync().modified;
          final dateB = b.statSync().modified;
          comparison = dateA.compareTo(dateB);
          break;
        case SortBy.type:
          final extA = a.path.split('.').last.toLowerCase();
          final extB = b.path.split('.').last.toLowerCase();
          comparison = extA.compareTo(extB);
          break;
      }

      return state.sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return filtered;
  }

  void toggleSelection(FileSystemEntity entity) {
    final selectedEntities = List<FileSystemEntity>.from(
      state.selectedEntities,
    );

    if (selectedEntities.contains(entity)) {
      selectedEntities.remove(entity);
    } else {
      selectedEntities.add(entity);
    }

    state = state.copyWith(
      selectedEntities: selectedEntities,
      isSelectionMode: selectedEntities.isNotEmpty,
    );
  }

  void selectAll() {
    state = state.copyWith(
      selectedEntities: List.from(state.entities),
      isSelectionMode: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(selectedEntities: [], isSelectionMode: false);
  }

  void toggleViewMode() {
    final newGridView = !state.isGridView;
    state = state.copyWith(isGridView: newGridView);
    SettingsService.instance.setIsGridView(newGridView);
  }

  void toggleHiddenFiles() {
    final newShowHidden = !state.showHiddenFiles;
    state = state.copyWith(showHiddenFiles: newShowHidden);
    SettingsService.instance.setShowHiddenFiles(newShowHidden);

    // Refresh current directory
    if (state.currentDirectory != null) {
      navigateToDirectory(state.currentDirectory!);
    }
  }

  void setSortBy(SortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
    SettingsService.instance.setSortBy(sortBy);

    // Re-sort current entities
    final sortedEntities = _filterAndSortEntities(state.entities);
    state = state.copyWith(entities: sortedEntities);
  }

  void setSortOrder(SortOrder sortOrder) {
    state = state.copyWith(sortOrder: sortOrder);
    SettingsService.instance.setSortOrder(sortOrder);

    // Re-sort current entities
    final sortedEntities = _filterAndSortEntities(state.entities);
    state = state.copyWith(entities: sortedEntities);
  }

  Future<void> copySelectedFiles() async {
    if (state.selectedEntities.isEmpty) return;

    await FileOperationsService.instance.copyFiles(state.selectedEntities);
    clearSelection();
  }

  Future<void> cutSelectedFiles() async {
    if (state.selectedEntities.isEmpty) return;

    await FileOperationsService.instance.cutFiles(state.selectedEntities);
    clearSelection();
  }

  Future<bool> pasteFiles() async {
    if (state.currentDirectory == null) return false;

    final success = await FileOperationsService.instance
        .pasteFilesWithPermissionCheck(state.currentDirectory!.path);

    if (success.success && state.currentDirectory != null) {
      await navigateToDirectory(state.currentDirectory!);
    }

    return success.success;
  }

  Future<bool> deleteSelectedFiles() async {
    if (state.selectedEntities.isEmpty) return false;

    final success = await FileOperationsService.instance
        .deleteFilesWithPermissionCheck(state.selectedEntities);

    if (success.success && state.currentDirectory != null) {
      await navigateToDirectory(state.currentDirectory!);
      clearSelection();
    }

    return success.success;
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        isSearching: false,
        searchQuery: '',
        searchResults: [],
      );
      return;
    }

    state = state.copyWith(isSearching: true, searchQuery: query);

    try {
      final results = await SearchService.instance.searchFiles(
        query: query,
        searchPath: state.currentDirectory?.path ?? '/storage/emulated/0',
        recursive: true,
      );

      state = state.copyWith(searchResults: results);
    } catch (e) {
      state = state.copyWith(error: 'Search failed: $e', searchResults: []);
    }
  }

  void clearSearch() {
    state = state.copyWith(
      isSearching: false,
      searchQuery: '',
      searchResults: [],
    );
  }
}

final fileBrowserProvider =
    NotifierProvider<FileBrowserNotifier, FileBrowserState>(
      () => FileBrowserNotifier(),
    );

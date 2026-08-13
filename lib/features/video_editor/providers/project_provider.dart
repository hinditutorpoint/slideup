import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/video_edit_settings.dart';
import '../services/hive_service.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ PROJECT STATE
// ═══════════════════════════════════════════════════════

@immutable
class ProjectState {
  final VideoProject? currentProject;
  final List<VideoProject> recentProjects;
  final List<VideoProject> allProjects;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final DateTime? lastSaved;

  const ProjectState({
    this.currentProject,
    this.recentProjects = const [],
    this.allProjects = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.lastSaved,
  });

  bool get hasUnsavedChanges {
    if (currentProject == null || lastSaved == null) return false;
    return currentProject!.modifiedAt.isAfter(lastSaved!);
  }

  bool get hasProject => currentProject != null;

  ProjectState copyWith({
    VideoProject? currentProject,
    List<VideoProject>? recentProjects,
    List<VideoProject>? allProjects,
    bool? isLoading,
    bool? isSaving,
    String? error,
    DateTime? lastSaved,
  }) {
    return ProjectState(
      currentProject: currentProject ?? this.currentProject,
      recentProjects: recentProjects ?? this.recentProjects,
      allProjects: allProjects ?? this.allProjects,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }

  ProjectState clearError() {
    return ProjectState(
      currentProject: currentProject,
      recentProjects: recentProjects,
      allProjects: allProjects,
      isLoading: isLoading,
      isSaving: isSaving,
      error: null,
      lastSaved: lastSaved,
    );
  }

  ProjectState clearProject() {
    return ProjectState(
      currentProject: null,
      recentProjects: recentProjects,
      allProjects: allProjects,
      isLoading: false,
      isSaving: false,
      error: null,
      lastSaved: null,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROJECT NOTIFIER
// ═══════════════════════════════════════════════════════

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier(this._hiveService) : super(const ProjectState());

  final HiveService _hiveService;
  final _uuid = const Uuid();

  static const int _maxRecentProjects = 10;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _loadAllProjects();
      await _loadRecentProjects();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Generates an incremental project name like "Project 1", "Project 2", "Project 3"...
  String getNextIncrementalProjectName([String prefix = 'Project']) {
    try {
      final existingProjects = state.allProjects;
      int maxNumber = 0;
      final regex = RegExp('^${RegExp.escape(prefix)}\\s*(\\d+)\$', caseSensitive: false);

      for (final project in existingProjects) {
        final match = regex.firstMatch(project.name.trim());
        if (match != null) {
          final numStr = match.group(1);
          if (numStr != null) {
            final val = int.tryParse(numStr);
            if (val != null && val > maxNumber) {
              maxNumber = val;
            }
          }
        }
      }

      if (maxNumber == 0) {
        maxNumber = existingProjects.length;
      }

      return '$prefix ${maxNumber + 1}';
    } catch (_) {
      return '$prefix 1';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CREATE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<VideoProject>> createProject({
    String? name,
    required String videoPath,
    required Duration videoDuration,
  }) async {
    return SafeAsync.run(() async {
      final resolvedName = (name == null ||
              name.trim().isEmpty ||
              name == 'Untitled Project' ||
              name == 'Untitled' ||
              name == 'New Project')
          ? getNextIncrementalProjectName()
          : name.trim();

      final project = VideoProject(
        id: _uuid.v4(),
        name: resolvedName,
        videoPath: videoPath,
        videoDuration: videoDuration,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        primaryVideoClips: videoPath.isNotEmpty
            ? [
                PrimaryVideoClip(
                  id: _uuid.v4(),
                  videoPath: videoPath,
                  sourceDuration: videoDuration,
                ),
              ]
            : const [],
      );

      state = state.copyWith(currentProject: project, lastSaved: null);

      // Auto-save
      await _saveProject(project);
      await _addToRecent(project);

      return project;
    }, operationName: 'createProject');
  }

  Future<Result<VideoProject>> createBlankProject({
    String? name,
    Duration defaultDuration = const Duration(seconds: 10),
  }) async {
    return createProject(
      name: name,
      videoPath: '',
      videoDuration: defaultDuration,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OPEN PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<VideoProject>> openProject(String projectId) async {
    state = state.copyWith(isLoading: true);

    return SafeAsync.run(() async {
      final jsonStr = _hiveService.projectsBox?.get(projectId);

      if (jsonStr == null) {
        throw Exception('Project not found');
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final project = VideoProject.fromJson(json);

      state = state.copyWith(
        currentProject: project,
        isLoading: false,
        lastSaved: project.modifiedAt,
      );

      await _addToRecent(project);

      return project;
    }, operationName: 'openProject').whenComplete(() {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SAVE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> saveProject() async {
    if (state.currentProject == null) {
      return Result.failure(Exception('No project to save'));
    }

    state = state.copyWith(isSaving: true);

    return SafeAsync.run(() async {
      final project = state.currentProject!.copyWith(
        modifiedAt: DateTime.now(),
      );

      await _saveProject(project);

      state = state.copyWith(
        currentProject: project,
        isSaving: false,
        lastSaved: DateTime.now(),
      );

      debugPrint('✅ Project saved: ${project.name}');
    }, operationName: 'saveProject').whenComplete(() {
      if (state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
    });
  }

  Future<void> _saveProject(VideoProject project) async {
    final jsonStr = jsonEncode(project.toJson());
    await _hiveService.projectsBox?.put(project.id, jsonStr);
    await _loadAllProjects();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SAVE AS NEW PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<VideoProject>> saveAsNewProject(String newName) async {
    if (state.currentProject == null) {
      return Result.failure(Exception('No project to save'));
    }

    return SafeAsync.run(() async {
      final newProject = state.currentProject!.copyWith(
        id: _uuid.v4(),
        name: newName,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      await _saveProject(newProject);
      await _addToRecent(newProject);

      state = state.copyWith(
        currentProject: newProject,
        lastSaved: DateTime.now(),
      );

      return newProject;
    }, operationName: 'saveAsNewProject');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DELETE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> deleteProject(String projectId) async {
    return SafeAsync.run(() async {
      await _hiveService.projectsBox?.delete(projectId);
      await _removeFromRecent(projectId);

      if (state.currentProject?.id == projectId) {
        state = state.clearProject();
      }

      await _loadAllProjects();

      debugPrint('✅ Project deleted: $projectId');
    }, operationName: 'deleteProject');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RENAME PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> renameProject(String projectId, String newName) async {
    return SafeAsync.run(() async {
      final jsonStr = _hiveService.projectsBox?.get(projectId);
      if (jsonStr == null) throw Exception('Project not found');

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final project = VideoProject.fromJson(json);

      final updatedProject = project.copyWith(
        name: newName,
        modifiedAt: DateTime.now(),
      );

      await _saveProject(updatedProject);

      if (state.currentProject?.id == projectId) {
        state = state.copyWith(currentProject: updatedProject);
      }

      debugPrint('✅ Project renamed: $newName');
    }, operationName: 'renameProject');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DUPLICATE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<VideoProject>> duplicateProject(String projectId) async {
    return SafeAsync.run(() async {
      final jsonStr = _hiveService.projectsBox?.get(projectId);
      if (jsonStr == null) throw Exception('Project not found');

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final project = VideoProject.fromJson(json);

      final duplicatedProject = project.copyWith(
        id: _uuid.v4(),
        name: '${project.name} (Copy)',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      await _saveProject(duplicatedProject);

      return duplicatedProject;
    }, operationName: 'duplicateProject');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UPDATE CURRENT PROJECT
  // ═══════════════════════════════════════════════════════

  void updateCurrentProject(VideoProject project) {
    state = state.copyWith(
      currentProject: project.copyWith(modifiedAt: DateTime.now()),
    );
  }

  void updateTrim(Duration trimStart, Duration trimEnd) {
    if (state.currentProject == null) return;

    state = state.copyWith(
      currentProject: state.currentProject!.copyWith(
        trimStart: trimStart,
        trimEnd: trimEnd,
        modifiedAt: DateTime.now(),
      ),
    );
  }

  void updateColorGrade(ColorGradeSettings colorGrade) {
    if (state.currentProject == null) return;

    state = state.copyWith(
      currentProject: state.currentProject!.copyWith(
        colorGrade: colorGrade,
        modifiedAt: DateTime.now(),
      ),
    );
  }

  void updateExportPreset(ExportPreset preset) {
    if (state.currentProject == null) return;

    state = state.copyWith(
      currentProject: state.currentProject!.copyWith(
        exportPreset: preset,
        modifiedAt: DateTime.now(),
      ),
    );
  }

  void updateVideoAudioSettings(VideoAudioSettings settings) {
    final current = state.currentProject;
    if (current == null) return;

    final updated = current.copyWith(
      videoAudioSettings: settings,
      modifiedAt: DateTime.now(),
    );

    state = state.copyWith(currentProject: updated, isSaving: true);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLOSE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> closeProject({bool save = true}) async {
    if (save && state.hasUnsavedChanges) {
      final saveResult = await saveProject();
      if (saveResult.isFailure) {
        return Result.failure(saveResult.error!);
      }
    }

    state = state.clearProject();
    return Result.success(null);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RECENT PROJECTS
  // ═══════════════════════════════════════════════════════

  Future<void> _addToRecent(VideoProject project) async {
    try {
      final recentIds = await _getRecentProjectIds();

      // Remove if already exists
      recentIds.remove(project.id);

      // Add to front
      recentIds.insert(0, project.id);

      // Limit to max
      if (recentIds.length > _maxRecentProjects) {
        recentIds.removeRange(_maxRecentProjects, recentIds.length);
      }

      await _hiveService.recentProjectsBox?.put(
        'recent_ids',
        jsonEncode(recentIds),
      );
      await _loadRecentProjects();
    } catch (e) {
      debugPrint('❌ Add to recent error: $e');
    }
  }

  Future<void> _removeFromRecent(String projectId) async {
    try {
      final recentIds = await _getRecentProjectIds();
      recentIds.remove(projectId);
      await _hiveService.recentProjectsBox?.put(
        'recent_ids',
        jsonEncode(recentIds),
      );
      await _loadRecentProjects();
    } catch (e) {
      debugPrint('❌ Remove from recent error: $e');
    }
  }

  Future<List<String>> _getRecentProjectIds() async {
    try {
      final jsonStr = _hiveService.recentProjectsBox?.get('recent_ids');
      if (jsonStr != null) {
        return List<String>.from(jsonDecode(jsonStr) as List);
      }
    } catch (e) {
      debugPrint('❌ Get recent project ids error: $e');
    }
    return [];
  }

  Future<void> _loadRecentProjects() async {
    try {
      final recentIds = await _getRecentProjectIds();
      final projects = <VideoProject>[];

      for (final id in recentIds) {
        final jsonStr = _hiveService.projectsBox?.get(id);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          projects.add(VideoProject.fromJson(json));
        }
      }

      state = state.copyWith(recentProjects: projects);
    } catch (e) {
      debugPrint('❌ Load recent projects error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ALL PROJECTS
  // ═══════════════════════════════════════════════════════

  Future<void> _loadAllProjects() async {
    try {
      final projects = <VideoProject>[];
      final keys = _hiveService.projectsBox?.keys ?? [];

      for (final key in keys) {
        final jsonStr = _hiveService.projectsBox?.get(key);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          projects.add(VideoProject.fromJson(json));
        }
      }

      projects.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      state = state.copyWith(allProjects: projects);
    } catch (e) {
      debugPrint('❌ Load all projects error: $e');
    }
  }

  Future<void> refreshProjects() async {
    await _loadAllProjects();
    await _loadRecentProjects();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLEAR ERROR
  // ═══════════════════════════════════════════════════════

  void clearError() {
    state = state.clearError();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((
  ref,
) {
  final hiveService = ref.watch(hiveServiceProvider);
  return ProjectNotifier(hiveService);
});

// Convenience providers
final currentProjectProvider = Provider<VideoProject?>((ref) {
  return ref.watch(projectProvider).currentProject;
});

final recentProjectsProvider = Provider<List<VideoProject>>((ref) {
  return ref.watch(projectProvider).recentProjects;
});

final allProjectsProvider = Provider<List<VideoProject>>((ref) {
  return ref.watch(projectProvider).allProjects;
});

final hasUnsavedChangesProvider = Provider<bool>((ref) {
  return ref.watch(projectProvider).hasUnsavedChanges;
});

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'models/video_edit_settings.dart';
import 'services/video_edit_service.dart';
import 'services/thumbnail_service.dart';
import 'services/background_export_service.dart';
import 'components/unified_timeline.dart';
import 'components/draggable_preview.dart';
import 'tabs/trim_tab.dart';
import 'tabs/color_tab.dart';
import 'tabs/text_tab.dart';
import 'tabs/music_tab.dart';
import 'tabs/image_tab.dart';
import 'tabs/merge_tab.dart';
import 'tabs/audio_tab.dart';
import 'tabs/export_tab.dart';
import 'tabs/library_tab.dart';
import 'tabs/ai_tab.dart';

// ═══════════════════════════════════════════════════════
// ✅ EDITOR MODE
// ═══════════════════════════════════════════════════════

enum EditorMode { preview, timeline, tabs }

// ═══════════════════════════════════════════════════════
// ✅ UNDO/REDO ACTION
// ═══════════════════════════════════════════════════════

class EditorAction {
  final String type;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> newState;
  final DateTime timestamp;

  EditorAction({
    required this.type,
    required this.previousState,
    required this.newState,
  }) : timestamp = DateTime.now();
}

// ═══════════════════════════════════════════════════════
// ✅ PROJECT DATA (For Save/Load)
// ═══════════════════════════════════════════════════════

class EditorProjectData {
  final String id;
  final String name;
  final String videoPath;
  final Duration videoDuration;
  final double trimStartPercent;
  final double trimEndPercent;
  final ColorGradeSettings colorSettings;
  final List<TextTimelineItem> textItems;
  final List<ImageTimelineItem> imageItems;
  final List<AudioTimelineItem> audioItems;
  final ExportPreset exportPreset;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? thumbnailPath;

  EditorProjectData({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.videoDuration,
    this.trimStartPercent = 0.0,
    this.trimEndPercent = 1.0,
    this.colorSettings = const ColorGradeSettings(),
    this.textItems = const [],
    this.imageItems = const [],
    this.audioItems = const [],
    this.exportPreset = const ExportPreset(id: 'high_1080p', name: '1080p HD'),
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.thumbnailPath,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'videoPath': videoPath,
      'videoDuration': videoDuration.inMilliseconds,
      'trimStartPercent': trimStartPercent,
      'trimEndPercent': trimEndPercent,
      'colorSettings': colorSettings.toJson(),
      'textItems': textItems.map((t) => t.toJson()).toList(),
      'imageItems': imageItems.map((i) => i.toJson()).toList(),
      'audioItems': audioItems.map((a) => a.toJson()).toList(),
      'exportPreset': exportPreset.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory EditorProjectData.fromJson(Map<String, dynamic> json) {
    return EditorProjectData(
      id: json['id'] as String,
      name: json['name'] as String,
      videoPath: json['videoPath'] as String,
      videoDuration: Duration(milliseconds: json['videoDuration'] as int),
      trimStartPercent: (json['trimStartPercent'] as num?)?.toDouble() ?? 0.0,
      trimEndPercent: (json['trimEndPercent'] as num?)?.toDouble() ?? 1.0,
      colorSettings: json['colorSettings'] != null
          ? ColorGradeSettings.fromJson(json['colorSettings'])
          : const ColorGradeSettings(),
      textItems:
          (json['textItems'] as List?)
              ?.map((t) => _parseTextItem(t))
              .whereType<TextTimelineItem>()
              .toList() ??
          [],
      imageItems:
          (json['imageItems'] as List?)
              ?.map((i) => _parseImageItem(i))
              .whereType<ImageTimelineItem>()
              .toList() ??
          [],
      audioItems:
          (json['audioItems'] as List?)
              ?.map((a) => _parseAudioItem(a))
              .whereType<AudioTimelineItem>()
              .toList() ??
          [],
      exportPreset: json['exportPreset'] != null
          ? ExportPreset.fromJson(json['exportPreset'])
          : const ExportPreset(id: 'high_1080p', name: '1080p HD'),
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      modifiedAt: DateTime.tryParse(json['modifiedAt'] ?? ''),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  static TextTimelineItem? _parseTextItem(dynamic json) {
    try {
      if (json is! Map<String, dynamic>) return null;
      return TextTimelineItem(
        id: json['id'] as String,
        startTime: Duration(milliseconds: json['startTime'] as int),
        endTime: Duration(milliseconds: json['endTime'] as int),
        layer: json['layer'] as int? ?? 0,
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.8,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        isLocked: json['isLocked'] as bool? ?? false,
        isVisible: json['isVisible'] as bool? ?? true,
        text: json['text'] as String? ?? '',
        style: json['style'] != null
            ? TextOverlayStyle.fromJson(json['style'])
            : const TextOverlayStyle(),
        animationIn: TextAnimation.values[json['animationIn'] as int? ?? 0],
        animationOut: TextAnimation.values[json['animationOut'] as int? ?? 0],
      );
    } catch (e) {
      return null;
    }
  }

  static ImageTimelineItem? _parseImageItem(dynamic json) {
    try {
      if (json is! Map<String, dynamic>) return null;
      return ImageTimelineItem(
        id: json['id'] as String,
        startTime: Duration(milliseconds: json['startTime'] as int),
        endTime: Duration(milliseconds: json['endTime'] as int),
        layer: json['layer'] as int? ?? 0,
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        scale: (json['scale'] as num?)?.toDouble() ?? 0.3,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        isLocked: json['isLocked'] as bool? ?? false,
        isVisible: json['isVisible'] as bool? ?? true,
        imagePath: json['imagePath'] as String? ?? '',
        width: json['width'] as int? ?? 1920,
        height: json['height'] as int? ?? 1080,
        fit: ImageFit.values[json['fit'] as int? ?? 0],
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (e) {
      return null;
    }
  }

  static AudioTimelineItem? _parseAudioItem(dynamic json) {
    try {
      if (json is! Map<String, dynamic>) return null;
      return AudioTimelineItem(
        id: json['id'] as String,
        startTime: Duration(milliseconds: json['startTime'] as int),
        endTime: Duration(milliseconds: json['endTime'] as int),
        layer: json['layer'] as int? ?? -1,
        audioPath: json['audioPath'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        audioDuration: Duration(
          milliseconds: json['audioDuration'] as int? ?? 0,
        ),
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        isMuted: json['isMuted'] as bool? ?? false,
      );
    } catch (e) {
      return null;
    }
  }

  EditorProjectData copyWith({
    String? id,
    String? name,
    String? videoPath,
    Duration? videoDuration,
    double? trimStartPercent,
    double? trimEndPercent,
    ColorGradeSettings? colorSettings,
    List<TextTimelineItem>? textItems,
    List<ImageTimelineItem>? imageItems,
    List<AudioTimelineItem>? audioItems,
    ExportPreset? exportPreset,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? thumbnailPath,
  }) {
    return EditorProjectData(
      id: id ?? this.id,
      name: name ?? this.name,
      videoPath: videoPath ?? this.videoPath,
      videoDuration: videoDuration ?? this.videoDuration,
      trimStartPercent: trimStartPercent ?? this.trimStartPercent,
      trimEndPercent: trimEndPercent ?? this.trimEndPercent,
      colorSettings: colorSettings ?? this.colorSettings,
      textItems: textItems ?? this.textItems,
      imageItems: imageItems ?? this.imageItems,
      audioItems: audioItems ?? this.audioItems,
      exportPreset: exportPreset ?? this.exportPreset,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROJECT MANAGER
// ═══════════════════════════════════════════════════════

class ProjectManager {
  static final ProjectManager _instance = ProjectManager._internal();
  factory ProjectManager() => _instance;
  ProjectManager._internal();

  static const String _projectsFileName = 'editor_projects.json';
  static const int _maxRecentProjects = 10;

  Future<Directory> _getProjectsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory(p.join(appDir.path, 'editor_projects'));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  Future<File> _getProjectsFile() async {
    final dir = await _getProjectsDirectory();
    return File(p.join(dir.path, _projectsFileName));
  }

  Future<List<EditorProjectData>> loadAllProjects() async {
    try {
      final file = await _getProjectsFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);

      return jsonList
          .map((j) {
            try {
              return EditorProjectData.fromJson(j as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ Parse project error: $e');
              return null;
            }
          })
          .whereType<EditorProjectData>()
          .toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    } catch (e) {
      debugPrint('❌ Load projects error: $e');
      return [];
    }
  }

  Future<List<EditorProjectData>> getRecentProjects({int limit = 5}) async {
    final all = await loadAllProjects();
    return all.take(limit).toList();
  }

  Future<EditorProjectData?> loadProject(String projectId) async {
    try {
      final projects = await loadAllProjects();
      return projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => throw Exception('Project not found'),
      );
    } catch (e) {
      debugPrint('❌ Load project error: $e');
      return null;
    }
  }

  Future<bool> saveProject(EditorProjectData project) async {
    try {
      final projects = await loadAllProjects();
      final index = projects.indexWhere((p) => p.id == project.id);

      if (index >= 0) {
        projects[index] = project;
      } else {
        projects.insert(0, project);
      }

      // Limit to max projects
      while (projects.length > _maxRecentProjects * 2) {
        projects.removeLast();
      }

      final file = await _getProjectsFile();
      await file.writeAsString(
        json.encode(projects.map((p) => p.toJson()).toList()),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Save project error: $e');
      return false;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      final projects = await loadAllProjects();
      projects.removeWhere((p) => p.id == projectId);

      final file = await _getProjectsFile();
      await file.writeAsString(
        json.encode(projects.map((p) => p.toJson()).toList()),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Delete project error: $e');
      return false;
    }
  }

  Future<bool> renameProject(String projectId, String newName) async {
    try {
      final projects = await loadAllProjects();
      final index = projects.indexWhere((p) => p.id == projectId);

      if (index < 0) return false;

      projects[index] = projects[index].copyWith(name: newName);

      final file = await _getProjectsFile();
      await file.writeAsString(
        json.encode(projects.map((p) => p.toJson()).toList()),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Rename project error: $e');
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDITOR SHEET V2
// ═══════════════════════════════════════════════════════

class VideoEditorSheetPremium extends ConsumerStatefulWidget {
  final String videoPath;
  final Duration videoDuration;
  final Size? videoSize;
  final Function(String)? onExportComplete;
  final VoidCallback? onClose;
  final String? projectId; // For loading existing project

  const VideoEditorSheetPremium({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    this.videoSize,
    this.onExportComplete,
    this.onClose,
    this.projectId,
  });

  @override
  ConsumerState<VideoEditorSheetPremium> createState() =>
      _VideoEditorSheetPremiumState();
}

class _VideoEditorSheetPremiumState
    extends ConsumerState<VideoEditorSheetPremium>
    with TickerProviderStateMixin {
  // Controllers
  late TabController _tabController;

  // Services
  final VideoEditService _editService = VideoEditService();
  final ThumbnailService _thumbnailService = ThumbnailService();
  final BackgroundExportService _exportService = BackgroundExportService();
  final ProjectManager _projectManager = ProjectManager();
  final _uuid = const Uuid();

  // Editor state
  EditorMode _editorMode = EditorMode.preview;
  bool _isDisposed = false;
  bool _hasUnsavedChanges = false;
  String? _currentProjectId;
  String _projectName = 'Untitled Project';

  // Video state
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  Timer? _playbackTimer;

  // Trim state
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;

  // Color grading
  ColorGradeSettings _colorSettings = const ColorGradeSettings();

  // Timeline items
  List<TextTimelineItem> _textItems = [];
  List<ImageTimelineItem> _imageItems = [];
  List<AudioTimelineItem> _audioItems = [];

  // Selection
  String? _selectedItemId;

  // Media
  String? _selectedMusicPath;
  // ignore: unused_field
  MusicTrack? _selectedMusicTrack;
  List<StockImage> _selectedImages = [];
  String? _attachedAudioPath;

  // Export
  ExportPreset _selectedPreset = ExportPreset.defaultPresets[2];
  List<MediaItem> _libraryItems = [];
  List<MergeItem> _mergeQueue = [];

  // Preview
  Uint8List? _previewFrame;
  List<Uint8List> _thumbnails = [];

  // Processing
  bool _isProcessing = false;
  double _processProgress = 0.0;
  String _processMessage = '';

  // Undo/Redo
  final List<EditorAction> _undoStack = [];
  final List<EditorAction> _redoStack = [];
  static const int _maxUndoStackSize = 50;

  Timer? _previewDebounceTimer;

  // Recent projects
  List<EditorProjectData> _recentProjects = [];

  // Tab data - more compact icons
  static const _tabData = [
    (Icons.content_cut_rounded, 'Trim'),
    (Icons.palette_rounded, 'Color'),
    (Icons.text_fields_rounded, 'Text'),
    (Icons.music_note_rounded, 'Music'),
    (Icons.image_rounded, 'Image'),
    (Icons.auto_awesome_rounded, 'AI'),
    (Icons.merge_rounded, 'Merge'),
    (Icons.headphones_rounded, 'Audio'),
    (Icons.upload_rounded, 'Export'),
    (Icons.folder_rounded, 'Library'),
  ];

  // Computed properties
  Duration get _trimStart => Duration(
    milliseconds: (widget.videoDuration.inMilliseconds * _trimStartPercent)
        .toInt(),
  );

  Duration get _trimEnd => Duration(
    milliseconds: (widget.videoDuration.inMilliseconds * _trimEndPercent)
        .toInt(),
  );

  Duration get _trimDuration => _trimEnd - _trimStart;

  Size get _videoSize => widget.videoSize ?? const Size(1920, 1080);

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabData.length, vsync: this);
    _currentProjectId = widget.projectId ?? _uuid.v4();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Enable wakelock to keep screen on
      await WakelockPlus.enable();

      // Check and request permissions
      await _checkPermissions();

      // Initialize thumbnail service FIRST
      await _thumbnailService.initialize();

      // Initialize export service
      await _exportService.initialize();

      // Load existing project if projectId provided
      if (widget.projectId != null) {
        await _loadProject(widget.projectId!);
      }

      // Load recent projects
      await _loadRecentProjects();

      // Load thumbnails and preview
      await Future.wait([
        _loadThumbnails(),
        _loadPreviewFrame(),
        _loadLibrary(),
      ]);
    } catch (e) {
      debugPrint('❌ Initialize error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      // Check storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            // Try manage external storage for Android 11+
            final manageStatus = await Permission.manageExternalStorage.status;
            if (!manageStatus.isGranted) {
              await Permission.manageExternalStorage.request();
            }
          }
        }

        // For Android 13+, request media permissions
        if (await Permission.photos.status.isDenied) {
          await Permission.photos.request();
        }
        if (await Permission.audio.status.isDenied) {
          await Permission.audio.request();
        }
        if (await Permission.videos.status.isDenied) {
          await Permission.videos.request();
        }
      } else if (Platform.isIOS) {
        if (await Permission.photos.status.isDenied) {
          await Permission.photos.request();
        }
        if (await Permission.mediaLibrary.status.isDenied) {
          await Permission.mediaLibrary.request();
        }
      }

      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('❌ Check permissions error: $e');
    }
  }

  Future<void> _loadProject(String projectId) async {
    try {
      final project = await _projectManager.loadProject(projectId);
      if (project != null && mounted) {
        setState(() {
          _currentProjectId = project.id;
          _projectName = project.name;
          _trimStartPercent = project.trimStartPercent;
          _trimEndPercent = project.trimEndPercent;
          _colorSettings = project.colorSettings;
          _textItems = List.from(project.textItems);
          _imageItems = List.from(project.imageItems);
          _audioItems = List.from(project.audioItems);
          _selectedPreset = project.exportPreset;
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load project error: $e');
    }
  }

  Future<void> _loadRecentProjects() async {
    try {
      final projects = await _projectManager.getRecentProjects(limit: 5);
      if (mounted) {
        setState(() => _recentProjects = projects);
      }
    } catch (e) {
      debugPrint('❌ Load recent projects error: $e');
    }
  }

  Future<void> _loadThumbnails() async {
    if (_isDisposed) return;
    try {
      // Try sequential method first
      var thumbs = await _thumbnailService.generateTimelineThumbnails(
        videoPath: widget.videoPath,
        videoDuration: widget.videoDuration,
        count: 10,
        width: 120,
        height: 68,
      );

      // If failed, try batch method
      /* if (thumbs.isEmpty) {
        debugPrint(
          '⚠️ Sequential thumbnail generation failed, trying batch...',
        );
        thumbs = await _thumbnailService.generateThumbnailsBatch(
          videoPath: widget.videoPath,
          videoDuration: widget.videoDuration,
          count: 10,
          width: 120,
          height: 68,
        );
      } */

      if (mounted) setState(() => _thumbnails = thumbs);
    } catch (e) {
      debugPrint('❌ Load thumbnails error: $e');
    }
  }

  Future<void> _loadPreviewFrame() async {
    if (_isDisposed) return;

    try {
      Uint8List? frame;

      // Try up to 3 times
      for (int attempt = 0; attempt < 3 && frame == null; attempt++) {
        frame = await _thumbnailService.getThumbnailAtPosition(
          videoPath: widget.videoPath,
          position: _currentPosition,
          width: 720,
          height: 405,
        );

        if (frame == null && attempt < 2) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }

      if (mounted && frame != null) {
        setState(() => _previewFrame = frame);
      }
    } catch (e) {
      debugPrint('❌ Load preview error: $e');
    }
  }

  Future<void> _loadLibrary() async {
    if (_isDisposed) return;
    try {
      final items = await _editService.getLibraryItems();
      if (mounted) setState(() => _libraryItems = items);
    } catch (e) {
      debugPrint('❌ Load library error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _thumbnailService.dispose();
    _playbackTimer?.cancel();
    _previewDebounceTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UNDO/REDO IMPLEMENTATION
  // ═══════════════════════════════════════════════════════

  void _recordAction(String type, Map<String, dynamic> previousState) {
    try {
      final newState = _getCurrentState();

      final action = EditorAction(
        type: type,
        previousState: previousState,
        newState: newState,
      );

      _undoStack.add(action);
      _redoStack.clear();

      // Limit stack size
      while (_undoStack.length > _maxUndoStackSize) {
        _undoStack.removeAt(0);
      }

      _hasUnsavedChanges = true;
    } catch (e) {
      debugPrint('❌ Record action error: $e');
    }
  }

  Map<String, dynamic> _getCurrentState() {
    return {
      'trimStartPercent': _trimStartPercent,
      'trimEndPercent': _trimEndPercent,
      'colorSettings': _colorSettings.toJson(),
      'textItems': _textItems.map((t) => t.toJson()).toList(),
      'imageItems': _imageItems.map((i) => i.toJson()).toList(),
      'audioItems': _audioItems.map((a) => a.toJson()).toList(),
    };
  }

  void _applyState(Map<String, dynamic> state) {
    try {
      setState(() {
        _trimStartPercent =
            (state['trimStartPercent'] as num?)?.toDouble() ?? 0.0;
        _trimEndPercent = (state['trimEndPercent'] as num?)?.toDouble() ?? 1.0;

        if (state['colorSettings'] != null) {
          _colorSettings = ColorGradeSettings.fromJson(state['colorSettings']);
        }

        _textItems =
            (state['textItems'] as List?)
                ?.map((t) => EditorProjectData._parseTextItem(t))
                .whereType<TextTimelineItem>()
                .toList() ??
            [];

        _imageItems =
            (state['imageItems'] as List?)
                ?.map((i) => EditorProjectData._parseImageItem(i))
                .whereType<ImageTimelineItem>()
                .toList() ??
            [];

        _audioItems =
            (state['audioItems'] as List?)
                ?.map((a) => EditorProjectData._parseAudioItem(a))
                .whereType<AudioTimelineItem>()
                .toList() ??
            [];
      });

      _loadPreviewFrame();
    } catch (e) {
      debugPrint('❌ Apply state error: $e');
    }
  }

  void _undo() {
    if (!_canUndo) return;

    try {
      final action = _undoStack.removeLast();
      _redoStack.add(action);
      _applyState(action.previousState);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Undo error: $e');
    }
  }

  void _redo() {
    if (!_canRedo) return;

    try {
      final action = _redoStack.removeLast();
      _undoStack.add(action);
      _applyState(action.newState);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Redo error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PROJECT SAVE/LOAD/DELETE
  // ═══════════════════════════════════════════════════════

  Future<void> _saveProject() async {
    try {
      final project = EditorProjectData(
        id: _currentProjectId!,
        name: _projectName,
        videoPath: widget.videoPath,
        videoDuration: widget.videoDuration,
        trimStartPercent: _trimStartPercent,
        trimEndPercent: _trimEndPercent,
        colorSettings: _colorSettings,
        textItems: _textItems,
        imageItems: _imageItems,
        audioItems: _audioItems,
        exportPreset: _selectedPreset,
      );

      final success = await _projectManager.saveProject(project);

      if (success) {
        setState(() => _hasUnsavedChanges = false);
        await _loadRecentProjects();
        _showSuccess('Project saved');
      } else {
        _showError('Failed to save project');
      }
    } catch (e) {
      debugPrint('❌ Save project error: $e');
      _showError('Save failed: $e');
    }
  }

  Future<void> _saveProjectAs() async {
    final controller = TextEditingController(text: _projectName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Save Project As',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Project name',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _currentProjectId = _uuid.v4();
        _projectName = newName;
      });
      await _saveProject();
    }
  }

  void _showOpenProjectDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildProjectsSheet(ctx),
    );
  }

  Widget _buildProjectsSheet(BuildContext ctx) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                const Text(
                  'Recent Projects',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _loadRecentProjects();
                    if (mounted) {
                      _showOpenProjectDialog();
                    }
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Projects list
            Flexible(
              child: _recentProjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 48,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No saved projects',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _recentProjects.length,
                      itemBuilder: (context, index) {
                        final project = _recentProjects[index];
                        return _buildProjectTile(ctx, project);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectTile(BuildContext ctx, EditorProjectData project) {
    final isCurrentProject = project.id == _currentProjectId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentProject
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentProject
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.movie, color: Colors.white54),
        ),
        title: Text(
          project.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(project.modifiedAt),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: Colors.grey[850],
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: Colors.white70, size: 20),
                  SizedBox(width: 12),
                  Text('Open', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white70, size: 20),
                  SizedBox(width: 12),
                  Text('Rename', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            Navigator.pop(ctx);
            switch (value) {
              case 'open':
                await _loadProject(project.id);
                break;
              case 'rename':
                await _renameProjectDialog(project);
                break;
              case 'delete':
                await _deleteProjectDialog(project);
                break;
            }
          },
        ),
        onTap: () async {
          Navigator.pop(ctx);
          await _loadProject(project.id);
        },
      ),
    );
  }

  Future<void> _renameProjectDialog(EditorProjectData project) async {
    final controller = TextEditingController(text: project.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Rename Project',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != project.name) {
      final success = await _projectManager.renameProject(project.id, newName);
      if (success) {
        if (project.id == _currentProjectId) {
          setState(() => _projectName = newName);
        }
        await _loadRecentProjects();
        _showSuccess('Project renamed');
      }
    }
  }

  Future<void> _deleteProjectDialog(EditorProjectData project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Project?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${project.name}"?\nThis action cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _projectManager.deleteProject(project.id);
      if (success) {
        await _loadRecentProjects();
        _showSuccess('Project deleted');
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD UI
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // More aggressive compact detection
        final screenHeight = constraints.maxHeight;
        final isVeryCompact = screenHeight < 500;
        final isCompact = screenHeight < 650;

        // Calculate safe height percentage
        final heightPercent = isVeryCompact ? 0.99 : (isCompact ? 0.97 : 0.94);

        return Container(
          height: screenHeight * heightPercent,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 4),
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHandle(),
                    _buildHeader(isCompact, isVeryCompact),
                    _buildModeSelector(isVeryCompact),
                    Expanded(child: _buildContent(isCompact, isVeryCompact)),
                    _buildBottomBar(isVeryCompact),
                  ],
                ),
                if (_isProcessing) _buildProcessingOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 32,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isCompact, bool isVeryCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 4 : 6,
      ),
      child: Row(
        children: [
          // Close button
          _buildSmallIconButton(Icons.close, () {
            _handleClose();
          }, size: isVeryCompact ? 16 : 18),

          const SizedBox(width: 6),

          // Project info
          Expanded(
            child: GestureDetector(
              onTap: _showOpenProjectDialog,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _projectName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isVeryCompact ? 12 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasUnsavedChanges)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${_formatDuration(_trimDuration)} • Tap to open project',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isVeryCompact ? 9 : 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status indicators
          _buildStatusIndicators(isVeryCompact),

          const SizedBox(width: 4),

          // Undo/Redo
          _buildSmallIconButton(
            Icons.undo,
            _canUndo ? _undo : null,
            size: isVeryCompact ? 16 : 18,
            enabled: _canUndo,
          ),
          _buildSmallIconButton(
            Icons.redo,
            _canRedo ? _redo : null,
            size: isVeryCompact ? 16 : 18,
            enabled: _canRedo,
          ),

          const SizedBox(width: 4),

          // Menu button
          _buildMenuButton(isVeryCompact),
        ],
      ),
    );
  }

  Widget _buildSmallIconButton(
    IconData icon,
    VoidCallback? onTap, {
    double size = 18,
    bool enabled = true,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: enabled ? (color ?? Colors.white) : Colors.grey[700],
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(bool isVeryCompact) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.white,
        size: isVeryCompact ? 18 : 20,
      ),
      color: Colors.grey[850],
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Save', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'saveAs',
          child: Row(
            children: [
              Icon(Icons.save_as, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Save As...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Open Project', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.refresh, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Text('Reset All', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'save':
            _saveProject();
            break;
          case 'saveAs':
            _saveProjectAs();
            break;
          case 'open':
            _showOpenProjectDialog();
            break;
          case 'reset':
            _resetAll();
            break;
        }
      },
    );
  }

  void _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Reset All?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will reset all edits. Are you sure?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final previousState = _getCurrentState();

      setState(() {
        _trimStartPercent = 0.0;
        _trimEndPercent = 1.0;
        _colorSettings = const ColorGradeSettings();
        _textItems.clear();
        _imageItems.clear();
        _audioItems.clear();
        _selectedItemId = null;
      });

      _recordAction('reset_all', previousState);
      _loadPreviewFrame();
      _showSuccess('All edits reset');
    }
  }

  void _handleClose() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Unsaved Changes',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'You have unsaved changes. What would you like to do?',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      switch (result) {
        case 'save':
          await _saveProject();
          widget.onClose?.call();
          if (mounted) Navigator.pop(context);
          break;
        case 'discard':
          widget.onClose?.call();
          if (mounted) Navigator.pop(context);
          break;
        default:
          // Cancel - do nothing
          break;
      }
    } else {
      widget.onClose?.call();
      Navigator.pop(context);
    }
  }

  Widget _buildStatusIndicators(bool isVeryCompact) {
    final indicators = <Widget>[];
    final size = isVeryCompact ? 10.0 : 12.0;

    if (!_colorSettings.isDefault) {
      indicators.add(_buildMiniIndicator(Icons.palette, Colors.purple, size));
    }
    if (_textItems.isNotEmpty) {
      indicators.add(
        _buildMiniIndicator(Icons.text_fields, Colors.orange, size),
      );
    }
    if (_imageItems.isNotEmpty) {
      indicators.add(_buildMiniIndicator(Icons.image, Colors.green, size));
    }
    if (_audioItems.isNotEmpty || _selectedMusicPath != null) {
      indicators.add(_buildMiniIndicator(Icons.music_note, Colors.blue, size));
    }
    if (_mergeQueue.isNotEmpty) {
      indicators.add(_buildMiniIndicator(Icons.merge, Colors.cyan, size));
    }

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: indicators.take(4).toList(), // Limit to 4 indicators
    );
  }

  Widget _buildMiniIndicator(IconData icon, Color color, double size) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MODE SELECTOR
  // ═══════════════════════════════════════════════════════

  Widget _buildModeSelector(bool isVeryCompact) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 2 : 4,
      ),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildModeButton(
            EditorMode.preview,
            Icons.preview,
            'Preview',
            isVeryCompact,
          ),
          _buildModeButton(
            EditorMode.timeline,
            Icons.view_timeline,
            'Timeline',
            isVeryCompact,
          ),
          _buildModeButton(
            EditorMode.tabs,
            Icons.dashboard,
            'Tools',
            isVeryCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    EditorMode mode,
    IconData icon,
    String label,
    bool isVeryCompact,
  ) {
    final isActive = _editorMode == mode;
    final height = isVeryCompact ? 28.0 : 32.0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _editorMode = mode);
          HapticFeedback.selectionClick();
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isActive ? Colors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isVeryCompact ? 14 : 16,
                color: isActive ? Colors.white : Colors.white54,
              ),
              if (!isVeryCompact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MAIN CONTENT
  // ═══════════════════════════════════════════════════════

  Widget _buildContent(bool isCompact, bool isVeryCompact) {
    switch (_editorMode) {
      case EditorMode.preview:
        return _buildPreviewMode(isCompact, isVeryCompact);
      case EditorMode.timeline:
        return _buildTimelineMode(isCompact, isVeryCompact);
      case EditorMode.tabs:
        return _buildTabsMode(isCompact, isVeryCompact);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW MODE
  // ═══════════════════════════════════════════════════════

  Widget _buildPreviewMode(bool isCompact, bool isVeryCompact) {
    return Column(
      children: [
        // Draggable preview (main area)
        Expanded(
          flex: isVeryCompact ? 5 : 6,
          child: Padding(
            padding: EdgeInsets.all(isVeryCompact ? 6 : 8),
            child: DraggablePreview(
              previewFrame: _previewFrame,
              videoSize: _videoSize,
              textItems: _textItems,
              imageItems: _imageItems,
              currentPosition: _currentPosition,
              colorGrade: _colorSettings,
              onTextItemUpdated: _updateTextItem,
              onImageItemUpdated: _updateImageItem,
              onItemSelected: (id) => setState(() => _selectedItemId = id),
              selectedItemId: _selectedItemId,
              isPlaying: _isPlaying,
              onPlayPause: _togglePlayback,
            ),
          ),
        ),

        // Mini timeline
        Container(
          height: isVeryCompact ? 50 : 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildMiniTimeline(isVeryCompact),
        ),

        // Quick actions
        _buildQuickActions(isVeryCompact),
      ],
    );
  }

  Widget _buildMiniTimeline(bool isVeryCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Scrubber
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                try {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;

                  final width = box.size.width - 16;
                  final percent = (details.localPosition.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                  final position = Duration(
                    milliseconds:
                        (percent * widget.videoDuration.inMilliseconds).toInt(),
                  );

                  setState(() => _currentPosition = position);
                  _loadPreviewFrame();
                } catch (e) {
                  debugPrint('❌ Scrub error: $e');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    return Stack(
                      children: [
                        // Thumbnails
                        if (_thumbnails.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: _thumbnails.map((thumb) {
                                return Expanded(
                                  child: Image.memory(thumb, fit: BoxFit.cover),
                                );
                              }).toList(),
                            ),
                          ),

                        // Trim overlay
                        Row(
                          children: [
                            Container(
                              width: width * _trimStartPercent,
                              color: Colors.black54,
                            ),
                            const Spacer(),
                            Container(
                              width: width * (1 - _trimEndPercent),
                              color: Colors.black54,
                            ),
                          ],
                        ),

                        // Playhead
                        Positioned(
                          left:
                              width *
                              (_currentPosition.inMilliseconds /
                                  widget.videoDuration.inMilliseconds),
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: Colors.red),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Time display
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isVeryCompact ? 2 : 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVeryCompact ? 9 : 10,
                  ),
                ),
                Text(
                  _formatDuration(widget.videoDuration),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isVeryCompact ? 9 : 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isVeryCompact) {
    final buttonSize = isVeryCompact ? 36.0 : 44.0;
    final iconSize = isVeryCompact ? 18.0 : 22.0;

    return Container(
      height: isVeryCompact ? 50 : 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.text_fields,
            label: 'Text',
            color: Colors.orange,
            onTap: _addTextOverlay,
            buttonSize: buttonSize,
            iconSize: iconSize,
            isVeryCompact: isVeryCompact,
          ),
          _buildQuickActionButton(
            icon: Icons.image,
            label: 'Image',
            color: Colors.green,
            onTap: () {
              setState(() => _editorMode = EditorMode.tabs);
              _tabController.animateTo(4);
            },
            buttonSize: buttonSize,
            iconSize: iconSize,
            isVeryCompact: isVeryCompact,
          ),
          _buildQuickActionButton(
            icon: Icons.music_note,
            label: 'Audio',
            color: Colors.purple,
            onTap: () {
              setState(() => _editorMode = EditorMode.tabs);
              _tabController.animateTo(3);
            },
            buttonSize: buttonSize,
            iconSize: iconSize,
            isVeryCompact: isVeryCompact,
          ),
          _buildQuickActionButton(
            icon: Icons.auto_awesome,
            label: 'AI',
            color: Colors.pink,
            onTap: () {
              setState(() => _editorMode = EditorMode.tabs);
              _tabController.animateTo(5);
            },
            buttonSize: buttonSize,
            iconSize: iconSize,
            isVeryCompact: isVeryCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double buttonSize,
    required double iconSize,
    required bool isVeryCompact,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          if (!isVeryCompact) ...[
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 9)),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE MODE
  // ═══════════════════════════════════════════════════════

  Widget _buildTimelineMode(bool isCompact, bool isVeryCompact) {
    return Column(
      children: [
        // Small preview
        Container(
          height: isVeryCompact ? 80 : 100,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: DraggablePreview(
            previewFrame: _previewFrame,
            videoSize: _videoSize,
            textItems: _textItems,
            imageItems: _imageItems,
            currentPosition: _currentPosition,
            colorGrade: _colorSettings,
            onTextItemUpdated: _updateTextItem,
            onImageItemUpdated: _updateImageItem,
            onItemSelected: (id) => setState(() => _selectedItemId = id),
            selectedItemId: _selectedItemId,
            isPlaying: _isPlaying,
            onPlayPause: _togglePlayback,
          ),
        ),

        const SizedBox(height: 4),

        // Unified timeline part 2 snippet
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: UnifiedTimeline(
              totalDuration: widget.videoDuration,
              currentPosition: _currentPosition,
              textItems: _textItems,
              imageItems: _imageItems,
              audioItems: _audioItems,
              videoThumbnails: _thumbnails,
              onPositionChanged: (pos) {
                setState(() => _currentPosition = pos);
                _loadPreviewFrame();
              },
              onTextItemsChanged: (items) {
                final previousState = _getCurrentState();
                setState(() => _textItems = items);
                _recordAction('text_timeline_change', previousState);
              },
              onImageItemsChanged: (items) {
                final previousState = _getCurrentState();
                setState(() => _imageItems = items);
                _recordAction('image_timeline_change', previousState);
              },
              onAudioItemsChanged: (items) {
                final previousState = _getCurrentState();
                setState(() => _audioItems = items);
                _recordAction('audio_timeline_change', previousState);
              },
              onItemSelected: (item) {
                setState(() => _selectedItemId = item?.id);
              },
              isPlaying: _isPlaying,
              trimStartPercent: _trimStartPercent,
              trimEndPercent: _trimEndPercent,
            ),
          ),
        ),

        // Playback controls
        _buildPlaybackControls(isVeryCompact),
      ],
    );
  }

  Widget _buildPlaybackControls(bool isVeryCompact) {
    final buttonSize = isVeryCompact ? 36.0 : 44.0;
    final iconSize = isVeryCompact ? 20.0 : 24.0;
    final playIconSize = isVeryCompact ? 24.0 : 28.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 4 : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skip back
          _buildControlButton(
            icon: Icons.skip_previous,
            onTap: () {
              setState(() => _currentPosition = _trimStart);
              _loadPreviewFrame();
            },
            size: iconSize,
          ),

          // Rewind
          _buildControlButton(
            icon: Icons.replay_5,
            onTap: () {
              final newPos = _currentPosition - const Duration(seconds: 5);
              setState(
                () => _currentPosition = newPos < _trimStart
                    ? _trimStart
                    : newPos,
              );
              _loadPreviewFrame();
            },
            size: iconSize,
          ),

          const SizedBox(width: 8),

          // Play/pause
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: playIconSize,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Forward
          _buildControlButton(
            icon: Icons.forward_5,
            onTap: () {
              final newPos = _currentPosition + const Duration(seconds: 5);
              setState(
                () => _currentPosition = newPos > _trimEnd ? _trimEnd : newPos,
              );
              _loadPreviewFrame();
            },
            size: iconSize,
          ),

          // Skip forward
          _buildControlButton(
            icon: Icons.skip_next,
            onTap: () {
              setState(() => _currentPosition = _trimEnd);
              _loadPreviewFrame();
            },
            size: iconSize,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white70, size: size),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TABS MODE
  // ═══════════════════════════════════════════════════════

  Widget _buildTabsMode(bool isCompact, bool isVeryCompact) {
    return Column(
      children: [
        // Small preview (only show if not very compact)
        if (!isVeryCompact)
          Container(
            height: isCompact ? 80 : 100,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _previewFrame != null
                  ? ColorFiltered(
                      colorFilter: _buildColorFilter(_colorSettings),
                      child: Image.memory(_previewFrame!, fit: BoxFit.contain),
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 32,
                        ),
                      ),
                    ),
            ),
          ),

        // Tab bar
        _buildTabBar(isVeryCompact),

        // Tab content
        Expanded(child: _buildTabContent(isVeryCompact)),
      ],
    );
  }

  Widget _buildTabBar(bool isVeryCompact) {
    return Container(
      height: isVeryCompact ? 36 : 42,
      margin: EdgeInsets.only(top: isVeryCompact ? 2 : 4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.red,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelPadding: EdgeInsets.symmetric(horizontal: isVeryCompact ? 6 : 8),
        labelStyle: TextStyle(fontSize: isVeryCompact ? 9 : 10),
        tabs: _tabData.map((data) {
          return Tab(
            icon: Icon(data.$1, size: isVeryCompact ? 14 : 16),
            iconMargin: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(bool isVeryCompact) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Trim
        TrimTab(
          videoPath: widget.videoPath,
          videoDuration: widget.videoDuration,
          thumbnails: _thumbnails,
          trimStartPercent: _trimStartPercent,
          trimEndPercent: _trimEndPercent,
          onTrimChanged: (start, end) {
            final previousState = _getCurrentState();
            try {
              setState(() {
                _trimStartPercent = start;
                _trimEndPercent = end;
              });
              _recordAction('trim_change', previousState);
              _loadPreviewFrame();
            } catch (e) {
              debugPrint('❌ Trim change error: $e');
            }
          },
        ),

        // Color
        ColorTab(
          settings: _colorSettings,
          onSettingsChanged: (settings) {
            final previousState = _getCurrentState();
            try {
              setState(() => _colorSettings = settings);
              _recordAction('color_change', previousState);
            } catch (e) {
              debugPrint('❌ Color change error: $e');
            }
          },
        ),

        // Text
        TextTab(
          overlays: _textItems
              .map(
                (t) => TextOverlay(
                  id: t.id,
                  text: t.text,
                  style: t.style,
                  animation: t.animationIn,
                  startTime: t.startTime,
                  endTime: t.endTime,
                  x: t.x,
                  y: t.y,
                  position: _getPositionFromXY(t.x, t.y),
                ),
              )
              .toList(),
          onOverlaysChanged: (overlays) {
            final previousState = _getCurrentState();
            try {
              setState(() {
                _textItems = overlays
                    .map(
                      (o) => TextTimelineItem(
                        id: o.id,
                        startTime: o.startTime,
                        endTime: o.endTime,
                        text: o.text,
                        style: o.style,
                        animationIn: o.animation,
                        x: o.x,
                        y: o.y,
                      ),
                    )
                    .toList();
              });
              _recordAction('text_change', previousState);
            } catch (e) {
              debugPrint('❌ Text change error: $e');
            }
          },
          videoDuration: widget.videoDuration,
        ),

        // Music
        MusicTab(
          selectedMusicPath: _selectedMusicPath,
          onMusicChanged: (path) {
            final previousState = _getCurrentState();
            try {
              setState(() => _selectedMusicPath = path);
              _recordAction('music_change', previousState);
            } catch (e) {
              debugPrint('❌ Music change error: $e');
            }
          },
          onMusicSelected: (track) {
            try {
              setState(() => _selectedMusicTrack = track);
              if (track.localPath != null) {
                _addAudioTrack(track);
              }
            } catch (e) {
              debugPrint('❌ Music select error: $e');
            }
          },
        ),

        // Images
        ImageTab(
          selectedImages: _selectedImages,
          onImagesChanged: (images) {
            try {
              setState(() => _selectedImages = images);
            } catch (e) {
              debugPrint('❌ Images change error: $e');
            }
          },
          onImageSelected: (image) {
            try {
              _addImageOverlay(image);
            } catch (e) {
              debugPrint('❌ Image select error: $e');
            }
          },
        ),

        // AI
        AiTab(
          onImageGenerated: (imageItem) {
            final previousState = _getCurrentState();
            try {
              setState(() => _imageItems.add(imageItem));
              _recordAction('ai_image_add', previousState);
            } catch (e) {
              debugPrint('❌ AI image error: $e');
            }
          },
          videoDuration: widget.videoDuration,
          currentPosition: _currentPosition,
        ),

        // Merge
        MergeTab(
          mergeQueue: _mergeQueue,
          onQueueChanged: (queue) {
            try {
              setState(() => _mergeQueue = queue);
            } catch (e) {
              debugPrint('❌ Merge queue error: $e');
            }
          },
          onAddVideo: _pickVideoForMerge,
          onAddImage: _pickImageForMerge,
        ),

        // Audio
        AudioTab(
          attachedAudioPath: _attachedAudioPath,
          onAudioChanged: (path) {
            final previousState = _getCurrentState();
            try {
              setState(() => _attachedAudioPath = path);
              _recordAction('audio_change', previousState);
            } catch (e) {
              debugPrint('❌ Audio change error: $e');
            }
          },
          onExtractAudio: _extractAudio,
        ),

        // Export
        ExportTab(
          selectedPreset: _selectedPreset,
          onPresetChanged: (preset) {
            try {
              setState(() => _selectedPreset = preset);
            } catch (e) {
              debugPrint('❌ Preset change error: $e');
            }
          },
          onExport: _exportVideo,
          onExportWithOptions: _showExportOptionsDialog,
          trimDuration: _trimDuration,
          hasColorGrading: !_colorSettings.isDefault,
          hasMergeQueue: _mergeQueue.isNotEmpty,
          hasAttachedAudio:
              _attachedAudioPath != null || _selectedMusicPath != null,
        ),

        // Library
        LibraryTab(
          items: _libraryItems,
          onRefresh: _loadLibrary,
          onDelete: _deleteLibraryItem,
          onRename: _renameLibraryItem,
          onShare: _shareLibraryItem,
          onEdit: _editLibraryItem,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BOTTOM BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomBar(bool isVeryCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: SizedBox(
              height: isVeryCompact ? 36 : 42,
              child: OutlinedButton(
                onPressed: _handleClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isVeryCompact ? 11 : 12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Save button
          SizedBox(
            height: isVeryCompact ? 36 : 42,
            child: OutlinedButton.icon(
              onPressed: _saveProject,
              icon: Icon(Icons.save, size: isVeryCompact ? 14 : 16),
              label: Text(
                'Save',
                style: TextStyle(fontSize: isVeryCompact ? 11 : 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: _hasUnsavedChanges ? Colors.orange : Colors.white24,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isVeryCompact ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Export button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: isVeryCompact ? 36 : 42,
              child: ElevatedButton.icon(
                onPressed: _exportVideo,
                icon: Icon(Icons.upload, size: isVeryCompact ? 14 : 16),
                label: Text(
                  'Export',
                  style: TextStyle(
                    fontSize: isVeryCompact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PROCESSING OVERLAY
  // ═══════════════════════════════════════════════════════

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: _processProgress > 0 ? _processProgress : null,
                color: Colors.red,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _processMessage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_processProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${(_processProgress * 100).toInt()}%',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                try {
                  _editService.cancelCurrentOperation();
                  setState(() => _isProcessing = false);
                } catch (e) {
                  debugPrint('❌ Cancel error: $e');
                }
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _togglePlayback() {
    try {
      if (_isPlaying) {
        _playbackTimer?.cancel();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          if (!mounted || !_isPlaying) {
            timer.cancel();
            return;
          }

          final newPos = _currentPosition + const Duration(milliseconds: 100);
          if (newPos >= _trimEnd) {
            setState(() {
              _currentPosition = _trimStart;
              _isPlaying = false;
            });
            timer.cancel();
          } else {
            setState(() => _currentPosition = newPos);
          }
          _loadPreviewFrame();
        });
      }
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('❌ Toggle playback error: $e');
    }
  }

  void _addTextOverlay() {
    final previousState = _getCurrentState();

    try {
      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newItem = TextTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: _currentPosition,
        endTime: _currentPosition + defaultDuration,
        text: 'New Text',
        x: 0.5,
        y: 0.8,
      );

      setState(() {
        _textItems.add(newItem);
        _selectedItemId = newItem.id;
      });

      _recordAction('add_text', previousState);
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Add text overlay error: $e');
    }
  }

  void _addImageOverlay(StockImage image) {
    final previousState = _getCurrentState();

    try {
      if (image.localPath == null) return;

      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newItem = ImageTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: _currentPosition,
        endTime: _currentPosition + defaultDuration,
        imagePath: image.localPath!,
        width: image.width,
        height: image.height,
        scale: 0.3,
      );

      setState(() {
        _imageItems.add(newItem);
        _selectedItemId = newItem.id;
      });

      _recordAction('add_image', previousState);
      HapticFeedback.mediumImpact();
      _showSuccess('Image added to timeline');
    } catch (e) {
      debugPrint('❌ Add image overlay error: $e');
    }
  }

  void _addAudioTrack(MusicTrack track) {
    final previousState = _getCurrentState();

    try {
      if (track.localPath == null) return;

      final newItem = AudioTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: track.duration < widget.videoDuration
            ? track.duration
            : widget.videoDuration,
        audioPath: track.localPath!,
        title: track.title,
        artist: track.artist,
        audioDuration: track.duration,
      );

      setState(() => _audioItems.add(newItem));
      _recordAction('add_audio', previousState);
      HapticFeedback.mediumImpact();
      _showSuccess('Audio added to timeline');
    } catch (e) {
      debugPrint('❌ Add audio track error: $e');
    }
  }

  void _updateTextItem(TextTimelineItem item) {
    final previousState = _getCurrentState();

    try {
      final index = _textItems.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        setState(() => _textItems[index] = item);
        _recordAction('update_text', previousState);
      }
    } catch (e) {
      debugPrint('❌ Update text item error: $e');
    }
  }

  void _updateImageItem(ImageTimelineItem item) {
    final previousState = _getCurrentState();

    try {
      final index = _imageItems.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        setState(() => _imageItems[index] = item);
        _recordAction('update_image', previousState);
      }
    } catch (e) {
      debugPrint('❌ Update image item error: $e');
    }
  }

  TextPositionCustom _getPositionFromXY(double x, double y) {
    if (y < 0.33) {
      if (x < 0.33) return TextPositionCustom.topLeft;
      if (x > 0.66) return TextPositionCustom.topRight;
      return TextPositionCustom.topCenter;
    } else if (y > 0.66) {
      if (x < 0.33) return TextPositionCustom.bottomLeft;
      if (x > 0.66) return TextPositionCustom.bottomRight;
      return TextPositionCustom.bottomCenter;
    } else {
      if (x < 0.33) return TextPositionCustom.centerLeft;
      if (x > 0.66) return TextPositionCustom.centerRight;
      return TextPositionCustom.center;
    }
  }

  Future<void> _exportVideo() async {
    if (_isProcessing) return;

    // Save project before export
    await _saveProject();

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Preparing...';
    });

    try {
      // Build project
      final project = VideoProject(
        id:
            _currentProjectId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _projectName,
        videoPath: widget.videoPath,
        videoDuration: widget.videoDuration,
        trimStart: _trimStart,
        trimEnd: _trimEnd,
        textItems: _textItems,
        imageItems: _imageItems,
        audioItems: _audioItems,
        colorGrade: _colorSettings,
        exportPreset: _selectedPreset,
      );

      // Start background export
      final result = await _exportService.startExport(
        project: project,
        runInBackground: true,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _processProgress = progress.progress;
              _processMessage = progress.message;
            });
          }
        },
      );

      if (result != null) {
        _showSuccess('Exported successfully!');
        widget.onExportComplete?.call(result);
        await _loadLibrary();
      } else {
        _showError('Export failed');
      }
    } catch (e) {
      debugPrint('❌ Export error: $e');
      _showError('Export error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _extractAudio() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processMessage = 'Extracting audio...';
    });

    try {
      final result = await _editService.extractAudio(
        inputPath: widget.videoPath,
        onProgress: (p) {
          if (mounted) setState(() => _processProgress = p);
        },
      );

      if (result != null) {
        _showSuccess('Audio extracted!');
        await _loadLibrary();
      } else {
        _showError('Extraction failed');
      }
    } catch (e) {
      debugPrint('❌ Extract audio error: $e');
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _pickVideoForMerge() {
    HapticFeedback.selectionClick();
    // TODO: Implement file picker for videos
    _showInfo('Video picker coming soon');
  }

  void _pickImageForMerge() {
    HapticFeedback.selectionClick();
    // TODO: Implement file picker for images
    _showInfo('Image picker coming soon');
  }

  void _showExportOptionsDialog() {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildExportOptionsSheet(ctx),
    );
  }

  Widget _buildExportOptionsSheet(BuildContext ctx) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Export Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Presets grid
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.5,
                ),
                itemCount: ExportPreset.defaultPresets.length,
                itemBuilder: (context, index) {
                  final preset = ExportPreset.defaultPresets[index];
                  final isSelected = _selectedPreset.id == preset.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedPreset = preset);
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? Colors.red : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name,
                            style: TextStyle(
                              color: isSelected ? Colors.red : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLibraryItem(MediaItem item) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Delete?', style: TextStyle(color: Colors.white)),
          content: Text(
            'Delete "${item.name}"?',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _editService.deleteFile(item.path);
        await _loadLibrary();
        _showSuccess('Deleted');
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      _showError('Delete failed');
    }
  }

  Future<void> _renameLibraryItem(MediaItem item) async {
    try {
      final controller = TextEditingController(text: item.name);

      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Rename', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Rename'),
            ),
          ],
        ),
      );

      if (newName != null && newName.isNotEmpty && newName != item.name) {
        await _editService.renameFile(item.path, newName);
        await _loadLibrary();
        _showSuccess('Renamed');
      }
    } catch (e) {
      debugPrint('❌ Rename error: $e');
      _showError('Rename failed');
    }
  }

  Future<void> _shareLibraryItem(MediaItem item) async {
    try {
      await _editService.shareFile(item.path);
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _showError('Share failed');
    }
  }

  void _editLibraryItem(MediaItem item) {
    HapticFeedback.selectionClick();
    _showInfo('Edit feature coming soon');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    try {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      if (h > 0) return '$h:$m:$s';
      return '$m:$s';
    } catch (e) {
      return '00:00';
    }
  }

  ColorFilter _buildColorFilter(ColorGradeSettings s) {
    try {
      final matrix = <double>[
        s.red * s.contrast,
        0,
        0,
        0,
        s.brightness * 50,
        0,
        s.green * s.contrast,
        0,
        0,
        s.brightness * 50,
        0,
        0,
        s.blue * s.contrast,
        0,
        s.brightness * 50,
        0,
        0,
        0,
        1,
        0,
      ];
      return ColorFilter.matrix(matrix);
    } catch (e) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Show success error: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Show error error: $e');
    }
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Show info error: $e');
    }
  }
}

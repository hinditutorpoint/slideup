import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
import 'components/smooth_video_preview.dart';
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
// ✅ CONSTANTS
// ═══════════════════════════════════════════════════════

class EditorConstants {
  static const double minScreenHeight = 400;
  static const double compactThreshold = 650;
  static const double veryCompactThreshold = 500;
  static const double minPreviewHeight = 80;
  static const double maxPreviewHeight = 300;
  static const int maxUndoStackSize = 50;
  static const int maxThumbnails = 10;
  static const Duration previewDebounce = Duration(milliseconds: 150);
  static const Duration playbackInterval = Duration(milliseconds: 100);
}

// ═══════════════════════════════════════════════════════
// ✅ EDITOR MODE
// ═══════════════════════════════════════════════════════

enum EditorMode { preview, timeline, tabs }

// ═══════════════════════════════════════════════════════
// ✅ UNDO/REDO ACTION
// ═══════════════════════════════════════════════════════

@immutable
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

@immutable
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
    try {
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
    } catch (e) {
      debugPrint('❌ EditorProjectData.toJson error: $e');
      return {};
    }
  }

  factory EditorProjectData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return EditorProjectData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Untitled',
        videoPath: '',
        videoDuration: Duration.zero,
      );
    }

    try {
      return EditorProjectData(
        id:
            json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Untitled',
        videoPath: json['videoPath'] as String? ?? '',
        videoDuration: Duration(
          milliseconds: (json['videoDuration'] as int?) ?? 0,
        ),
        trimStartPercent: (json['trimStartPercent'] as num?)?.toDouble() ?? 0.0,
        trimEndPercent: (json['trimEndPercent'] as num?)?.toDouble() ?? 1.0,
        colorSettings: json['colorSettings'] != null
            ? ColorGradeSettings.fromJson(
                json['colorSettings'] as Map<String, dynamic>?,
              )
            : const ColorGradeSettings(),
        textItems: _parseTextItems(json['textItems']),
        imageItems: _parseImageItems(json['imageItems']),
        audioItems: _parseAudioItems(json['audioItems']),
        exportPreset: json['exportPreset'] != null
            ? ExportPreset.fromJson(
                json['exportPreset'] as Map<String, dynamic>?,
              )
            : const ExportPreset(id: 'high_1080p', name: '1080p HD'),
        createdAt: _parseDateTime(json['createdAt']),
        modifiedAt: _parseDateTime(json['modifiedAt']),
        thumbnailPath: json['thumbnailPath'] as String?,
      );
    } catch (e) {
      debugPrint('❌ EditorProjectData.fromJson error: $e');
      return EditorProjectData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Untitled',
        videoPath: '',
        videoDuration: Duration.zero,
      );
    }
  }

  static List<TextTimelineItem> _parseTextItems(dynamic json) {
    try {
      if (json == null) return [];
      if (json is! List) return [];
      return json
          .map((t) => TextTimelineItem.fromJson(t as Map<String, dynamic>?))
          .toList();
    } catch (e) {
      debugPrint('❌ Parse text items error: $e');
      return [];
    }
  }

  static List<ImageTimelineItem> _parseImageItems(dynamic json) {
    try {
      if (json == null) return [];
      if (json is! List) return [];
      return json
          .map((i) => ImageTimelineItem.fromJson(i as Map<String, dynamic>?))
          .toList();
    } catch (e) {
      debugPrint('❌ Parse image items error: $e');
      return [];
    }
  }

  static List<AudioTimelineItem> _parseAudioItems(dynamic json) {
    try {
      if (json == null) return [];
      if (json is! List) return [];
      return json
          .map((a) => AudioTimelineItem.fromJson(a as Map<String, dynamic>?))
          .toList();
    } catch (e) {
      debugPrint('❌ Parse audio items error: $e');
      return [];
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
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
// ✅ PROJECT MANAGER (Singleton)
// ═══════════════════════════════════════════════════════

class ProjectManager {
  static final ProjectManager _instance = ProjectManager._internal();
  factory ProjectManager() => _instance;
  ProjectManager._internal();

  static const String _projectsFileName = 'editor_projects.json';
  static const int _maxRecentProjects = 10;

  Future<Directory> _getProjectsDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final projectsDir = Directory(p.join(appDir.path, 'editor_projects'));
      if (!await projectsDir.exists()) {
        await projectsDir.create(recursive: true);
      }
      return projectsDir;
    } catch (e) {
      debugPrint('❌ Get projects directory error: $e');
      rethrow;
    }
  }

  Future<File> _getProjectsFile() async {
    try {
      final dir = await _getProjectsDirectory();
      return File(p.join(dir.path, _projectsFileName));
    } catch (e) {
      debugPrint('❌ Get projects file error: $e');
      rethrow;
    }
  }

  Future<List<EditorProjectData>> loadAllProjects() async {
    try {
      final file = await _getProjectsFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

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
    try {
      final all = await loadAllProjects();
      return all.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Get recent projects error: $e');
      return [];
    }
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
      final jsonStr = json.encode(projects.map((p) => p.toJson()).toList());
      await file.writeAsString(jsonStr);

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
      final jsonStr = json.encode(projects.map((p) => p.toJson()).toList());
      await file.writeAsString(jsonStr);

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

      projects[index] = projects[index].copyWith(
        name: newName,
        modifiedAt: DateTime.now(),
      );

      final file = await _getProjectsFile();
      final jsonStr = json.encode(projects.map((p) => p.toJson()).toList());
      await file.writeAsString(jsonStr);

      return true;
    } catch (e) {
      debugPrint('❌ Rename project error: $e');
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDITOR SHEET - MAIN WIDGET
// ═══════════════════════════════════════════════════════

class VideoEditorSheet extends ConsumerStatefulWidget {
  final String videoPath;
  final Duration videoDuration;
  final Size? videoSize;
  final Function(String)? onExportComplete;
  final VoidCallback? onClose;
  final String? projectId;

  const VideoEditorSheet({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    this.videoSize,
    this.onExportComplete,
    this.onClose,
    this.projectId,
  });

  @override
  ConsumerState<VideoEditorSheet> createState() => _VideoEditorSheetState();
}

class _VideoEditorSheetState extends ConsumerState<VideoEditorSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ─────────────────────────────────────────────────────
  // Controllers
  // ─────────────────────────────────────────────────────
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // ─────────────────────────────────────────────────────
  // Services
  // ─────────────────────────────────────────────────────
  late final VideoEditService _editService;
  late final ThumbnailService _thumbnailService;
  late final BackgroundExportService _exportService;
  late final ProjectManager _projectManager;
  late final Uuid _uuid;

  // ─────────────────────────────────────────────────────
  // State flags
  // ─────────────────────────────────────────────────────
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _hasUnsavedChanges = false;
  bool _isProcessing = false;
  bool _isPlaying = false;

  // ─────────────────────────────────────────────────────
  // Editor state
  // ─────────────────────────────────────────────────────
  EditorMode _editorMode = EditorMode.preview;
  String? _currentProjectId;
  String _projectName = 'Untitled Project';

  // ─────────────────────────────────────────────────────
  // Video state
  // ─────────────────────────────────────────────────────
  Duration _currentPosition = Duration.zero;
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;

  // ─────────────────────────────────────────────────────
  // Editing state
  // ─────────────────────────────────────────────────────
  ColorGradeSettings _colorSettings = const ColorGradeSettings();
  List<TextTimelineItem> _textItems = [];
  List<ImageTimelineItem> _imageItems = [];
  List<AudioTimelineItem> _audioItems = [];
  String? _selectedItemId;

  // ─────────────────────────────────────────────────────
  // Media state
  // ─────────────────────────────────────────────────────
  String? _selectedMusicPath;
  MusicTrack? _selectedMusicTrack;
  List<StockImage> _selectedImages = [];
  String? _attachedAudioPath;

  // ─────────────────────────────────────────────────────
  // Export state
  // ─────────────────────────────────────────────────────
  ExportPreset _selectedPreset = ExportPreset.defaultPresets[2];
  List<MediaItem> _libraryItems = [];
  List<MergeItem> _mergeQueue = [];

  // ─────────────────────────────────────────────────────
  // Preview state
  // ─────────────────────────────────────────────────────
  Uint8List? _previewFrame;
  List<Uint8List> _thumbnails = [];

  // ─────────────────────────────────────────────────────
  // Processing state
  // ─────────────────────────────────────────────────────
  double _processProgress = 0.0;
  String _processMessage = '';

  // ─────────────────────────────────────────────────────
  // Undo/Redo
  // ─────────────────────────────────────────────────────
  final List<EditorAction> _undoStack = [];
  final List<EditorAction> _redoStack = [];

  // ─────────────────────────────────────────────────────
  // Timers
  // ─────────────────────────────────────────────────────
  Timer? _playbackTimer;
  Timer? _previewDebounceTimer;
  Timer? _autoSaveTimer;

  // ─────────────────────────────────────────────────────
  // Recent projects
  // ─────────────────────────────────────────────────────
  List<EditorProjectData> _recentProjects = [];

  // ─────────────────────────────────────────────────────
  // Tab data
  // ─────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────
  // Computed properties
  // ─────────────────────────────────────────────────────
  Duration get _trimStart => Duration(
    milliseconds: (widget.videoDuration.inMilliseconds * _trimStartPercent)
        .round(),
  );

  Duration get _trimEnd => Duration(
    milliseconds: (widget.videoDuration.inMilliseconds * _trimEndPercent)
        .round(),
  );

  Duration get _trimDuration => _trimEnd - _trimStart;

  Size get _videoSize => widget.videoSize ?? const Size(1920, 1080);

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  Duration _lastPositionUpdate = Duration.zero;

  // ═══════════════════════════════════════════════════════
  // ✅ LIFECYCLE
  // ═══════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _tabController = TabController(length: _tabData.length, vsync: this);
    _currentProjectId = widget.projectId ?? const Uuid().v4();
    _initializeAsync();
  }

  void _initializeServices() {
    try {
      _editService = VideoEditService();
      _thumbnailService = ThumbnailService();
      _exportService = BackgroundExportService();
      _projectManager = ProjectManager();
      _uuid = const Uuid();
    } catch (e) {
      debugPrint('❌ Initialize services error: $e');
    }
  }

  Future<void> _initializeAsync() async {
    if (_isDisposed) return;

    try {
      // Enable wakelock
      await WakelockPlus.enable();

      // Check permissions
      await _checkPermissions();

      // Initialize services
      await Future.wait([
        _thumbnailService.initialize(),
        _exportService.initialize(),
      ]);

      // Load existing project if provided
      if (widget.projectId != null) {
        await _loadProject(widget.projectId!);
      }

      // Load data
      await Future.wait([
        _loadRecentProjects(),
        _loadThumbnails(),
        _loadPreviewFrame(),
        _loadLibrary(),
      ]);

      // Start auto-save timer
      _startAutoSave();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Initialize async error: $e');
      if (mounted) {
        _showError('Failed to initialize editor: $e');
      }
    }
  }

  void _onVideoPositionChanged(Duration position) {
    if (_isDisposed || !mounted) return;

    // Debounce: only update if changed by >100ms
    if ((position - _lastPositionUpdate).abs() <
        const Duration(milliseconds: 100)) {
      return;
    }

    _lastPositionUpdate = position;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted && _isPlaying) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        final permissions = [
          Permission.storage,
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.notification,
        ];

        for (final permission in permissions) {
          if (await permission.isDenied) {
            await permission.request();
          }
        }

        // For Android 11+
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      } else if (Platform.isIOS) {
        await Permission.photos.request();
        await Permission.mediaLibrary.request();
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('❌ Check permissions error: $e');
    }
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_hasUnsavedChanges && !_isProcessing) {
        _saveProject();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (state == AppLifecycleState.paused) {
        _pausePlayback();
        if (_hasUnsavedChanges) {
          _saveProject();
        }
      }
    } catch (e) {
      debugPrint('❌ App lifecycle error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeResources();
    super.dispose();
  }

  void _disposeResources() {
    try {
      _tabController.dispose();
      _scrollController.dispose();
      _playbackTimer?.cancel();
      _previewDebounceTimer?.cancel();
      _autoSaveTimer?.cancel();
      _thumbnailService.dispose();
      WakelockPlus.disable();
    } catch (e) {
      debugPrint('❌ Dispose resources error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DATA LOADING
  // ═══════════════════════════════════════════════════════

  Future<void> _loadProject(String projectId) async {
    if (_isDisposed) return;

    try {
      final project = await _projectManager.loadProject(projectId);
      if (project != null && mounted) {
        setState(() {
          _currentProjectId = project.id;
          _projectName = project.name;
          _trimStartPercent = project.trimStartPercent.clamp(0.0, 1.0);
          _trimEndPercent = project.trimEndPercent.clamp(0.0, 1.0);
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
      if (mounted) _showError('Failed to load project');
    }
  }

  Future<void> _loadRecentProjects() async {
    if (_isDisposed) return;

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
      final thumbs = await _thumbnailService.generateTimelineThumbnails(
        videoPath: widget.videoPath,
        videoDuration: widget.videoDuration,
        count: EditorConstants.maxThumbnails,
        width: 120,
        height: 68,
      );

      if (mounted) {
        setState(() => _thumbnails = thumbs);
      }
    } catch (e) {
      debugPrint('❌ Load thumbnails error: $e');
    }
  }

  Future<void> _loadPreviewFrame() async {
    if (_isDisposed) return;

    try {
      final frame = await _thumbnailService.getThumbnailAtPosition(
        videoPath: widget.videoPath,
        position: _currentPosition,
        width: 720,
        height: 405,
      );

      if (mounted && frame != null) {
        setState(() => _previewFrame = frame);
      }
    } catch (e) {
      debugPrint('❌ Load preview error: $e');
    }
  }

  void _loadPreviewFrameDebounced() {
    _previewDebounceTimer?.cancel();
    _previewDebounceTimer = Timer(EditorConstants.previewDebounce, () {
      if (!_isDisposed) {
        _loadPreviewFrame();
      }
    });
  }

  Future<void> _loadLibrary() async {
    if (_isDisposed) return;

    try {
      final items = await _editService.getLibraryItems();
      if (mounted) {
        setState(() => _libraryItems = items);
      }
    } catch (e) {
      debugPrint('❌ Load library error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UNDO/REDO
  // ═══════════════════════════════════════════════════════

  void _recordAction(String type, Map<String, dynamic> previousState) {
    if (_isDisposed) return;

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
      while (_undoStack.length > EditorConstants.maxUndoStackSize) {
        _undoStack.removeAt(0);
      }

      _hasUnsavedChanges = true;
    } catch (e) {
      debugPrint('❌ Record action error: $e');
    }
  }

  Map<String, dynamic> _getCurrentState() {
    try {
      return {
        'trimStartPercent': _trimStartPercent,
        'trimEndPercent': _trimEndPercent,
        'colorSettings': _colorSettings.toJson(),
        'textItems': _textItems.map((t) => t.toJson()).toList(),
        'imageItems': _imageItems.map((i) => i.toJson()).toList(),
        'audioItems': _audioItems.map((a) => a.toJson()).toList(),
      };
    } catch (e) {
      debugPrint('❌ Get current state error: $e');
      return {};
    }
  }

  void _applyState(Map<String, dynamic> state) {
    if (_isDisposed) return;

    try {
      setState(() {
        _trimStartPercent =
            ((state['trimStartPercent'] as num?)?.toDouble() ?? 0.0).clamp(
              0.0,
              1.0,
            );
        _trimEndPercent = ((state['trimEndPercent'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.0, 1.0);

        if (state['colorSettings'] != null) {
          _colorSettings = ColorGradeSettings.fromJson(
            state['colorSettings'] as Map<String, dynamic>?,
          );
        }

        _textItems = EditorProjectData._parseTextItems(state['textItems']);
        _imageItems = EditorProjectData._parseImageItems(state['imageItems']);
        _audioItems = EditorProjectData._parseAudioItems(state['audioItems']);
      });

      _loadPreviewFrame();
    } catch (e) {
      debugPrint('❌ Apply state error: $e');
    }
  }

  void _undo() {
    if (!_canUndo || _isDisposed) return;

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
    if (!_canRedo || _isDisposed) return;

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
  // ✅ PROJECT MANAGEMENT
  // ═══════════════════════════════════════════════════════

  Future<void> _saveProject() async {
    if (_isDisposed || _currentProjectId == null) return;

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

      if (mounted) {
        if (success) {
          setState(() => _hasUnsavedChanges = false);
          await _loadRecentProjects();
          _showSuccess('Project saved');
        } else {
          _showError('Failed to save project');
        }
      }
    } catch (e) {
      debugPrint('❌ Save project error: $e');
      if (mounted) _showError('Save failed: $e');
    }
  }

  Future<void> _saveProjectAs() async {
    if (_isDisposed) return;

    final controller = TextEditingController(text: _projectName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _SaveAsDialog(controller: controller),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() {
        _currentProjectId = _uuid.v4();
        _projectName = newName;
      });
      await _saveProject();
    }
  }

  void _showOpenProjectDialog() {
    if (_isDisposed) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ProjectsSheet(
        projects: _recentProjects,
        currentProjectId: _currentProjectId,
        onRefresh: () async {
          await _loadRecentProjects();
          if (mounted) Navigator.pop(ctx);
          _showOpenProjectDialog();
        },
        onOpen: (project) async {
          Navigator.pop(ctx);
          await _loadProject(project.id);
        },
        onRename: _renameProjectDialog,
        onDelete: _deleteProjectDialog,
      ),
    );
  }

  Future<void> _renameProjectDialog(EditorProjectData project) async {
    if (_isDisposed) return;

    final controller = TextEditingController(text: project.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(controller: controller),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != project.name &&
        mounted) {
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
    if (_isDisposed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(projectName: project.name),
    );

    if (confirmed == true && mounted) {
      final success = await _projectManager.deleteProject(project.id);
      if (success) {
        await _loadRecentProjects();
        _showSuccess('Project deleted');
      }
    }
  }

  void _resetAll() async {
    if (_isDisposed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ResetConfirmDialog(),
    );

    if (confirmed == true && mounted) {
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
    if (_isDisposed) return;

    if (_hasUnsavedChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => const _UnsavedChangesDialog(),
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
      if (mounted) Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK CONTROL
  // ═══════════════════════════════════════════════════════

  void _togglePlayback() {
    if (_isDisposed) return;

    try {
      if (_isPlaying) {
        _pausePlayback();
      } else {
        _startPlayback();
      }
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('❌ Toggle playback error: $e');
    }
  }

  void _startPlayback() {
    if (_isDisposed) return;

    setState(() => _isPlaying = true);

    _playbackTimer = Timer.periodic(EditorConstants.playbackInterval, (timer) {
      if (_isDisposed || !_isPlaying) {
        timer.cancel();
        return;
      }

      final newPos = _currentPosition + EditorConstants.playbackInterval;
      if (newPos >= _trimEnd) {
        setState(() {
          _currentPosition = _trimStart;
          _isPlaying = false;
        });
        timer.cancel();
      } else {
        setState(() => _currentPosition = newPos);
      }
      _loadPreviewFrameDebounced();
    });
  }

  void _pausePlayback() {
    if (_isDisposed) return;

    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD METHODS
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          return _buildEditor(constraints);
        } catch (e) {
          debugPrint('❌ Build error: $e');
          return _buildErrorScreen(e.toString());
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('Loading editor...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load editor',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BoxConstraints constraints) {
    final screenHeight = constraints.maxHeight;
    final isVeryCompact = screenHeight < EditorConstants.veryCompactThreshold;
    final isCompact = screenHeight < EditorConstants.compactThreshold;
    final heightPercent = isVeryCompact ? 0.99 : (isCompact ? 0.97 : 0.94);

    return Container(
      height: math.max(
        screenHeight * heightPercent,
        EditorConstants.minScreenHeight,
      ),
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
              mainAxisSize: MainAxisSize.min,
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
  }

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

  // Helper methods for UI feedback
  void _showSuccess(String msg) {
    if (!mounted || _isDisposed) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(msg)),
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
    if (!mounted || _isDisposed) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(msg)),
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
    if (!mounted || _isDisposed) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(msg)),
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
      return ColorFilter.matrix(s.toColorMatrix());
    } catch (e) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONTINUATION - BUILD METHODS
  // ═══════════════════════════════════════════════════════

  // Add to _VideoEditorSheetState class:

  Widget _buildHeader(bool isCompact, bool isVeryCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Close button
            IconButton(
              onPressed: _handleClose,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                Icons.close,
                size: isVeryCompact ? 18 : 20,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 4),

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
                              fontSize: isVeryCompact ? 12 : 14,
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
                    if (!isVeryCompact)
                      Text(
                        _formatDuration(_trimDuration),
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),

            // Status indicators
            if (!isVeryCompact) _buildStatusIndicators(isVeryCompact),

            const SizedBox(width: 4),

            // Undo/Redo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _canUndo ? _undo : null,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.undo,
                    size: isVeryCompact ? 16 : 18,
                    color: _canUndo ? Colors.white : Colors.grey[700],
                  ),
                ),
                IconButton(
                  onPressed: _canRedo ? _redo : null,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.redo,
                    size: isVeryCompact ? 16 : 18,
                    color: _canRedo ? Colors.white : Colors.grey[700],
                  ),
                ),
              ],
            ),

            // Menu button
            _buildMenuButton(isVeryCompact),
          ],
        ),
      ),
    );
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

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: indicators.take(4).toList(),
      ),
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

  Widget _buildMenuButton(bool isVeryCompact) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.white,
        size: isVeryCompact ? 18 : 20,
      ),
      color: Colors.grey[850],
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      onSelected: (value) async {
        try {
          switch (value) {
            case 'save':
              await _saveProject();
              break;
            case 'saveAs':
              await _saveProjectAs();
              break;
            case 'open':
              _showOpenProjectDialog();
              break;
            case 'reset':
              _resetAll();
              break;
          }
        } catch (e) {
          debugPrint('❌ Menu action error: $e');
        }
      },
    );
  }

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
        children: EditorMode.values.map((mode) {
          return Expanded(child: _buildModeButton(mode, isVeryCompact));
        }).toList(),
      ),
    );
  }

  Widget _buildModeButton(EditorMode mode, bool isVeryCompact) {
    final isActive = _editorMode == mode;
    final height = isVeryCompact ? 28.0 : 32.0;

    IconData icon;
    String label;

    switch (mode) {
      case EditorMode.preview:
        icon = Icons.preview;
        label = 'Preview';
        break;
      case EditorMode.timeline:
        icon = Icons.view_timeline;
        label = 'Timeline';
        break;
      case EditorMode.tabs:
        icon = Icons.dashboard;
        label = 'Tools';
        break;
    }

    return GestureDetector(
      onTap: () {
        if (!_isDisposed) {
          setState(() => _editorMode = mode);
          HapticFeedback.selectionClick();
        }
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
    );
  }

  Widget _buildContent(bool isCompact, bool isVeryCompact) {
    try {
      switch (_editorMode) {
        case EditorMode.preview:
          return _buildPreviewMode(isCompact, isVeryCompact);
        case EditorMode.timeline:
          return _buildTimelineMode(isCompact, isVeryCompact);
        case EditorMode.tabs:
          return _buildTabsMode(isCompact, isVeryCompact);
      }
    } catch (e) {
      debugPrint('❌ Build content error: $e');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading content',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW MODE
  // ═══════════════════════════════════════════════════════

  Widget _buildPreviewMode(bool isCompact, bool isVeryCompact) {
    return Column(
      children: [
        // Main preview area
        Expanded(
          flex: isVeryCompact ? 5 : 6,
          child: Container(
            margin: EdgeInsets.all(isVeryCompact ? 6 : 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SmoothVideoPreview(
                videoPath: widget.videoPath,
                currentPosition: _currentPosition,
                trimStart: _trimStart,
                trimEnd: _trimEnd,
                isPlaying: _isPlaying,
                onPositionChanged: _onVideoPositionChanged,
                onPlayPause: _togglePlayback,
                // ✅ Overlay mode - transparent overlay on video
                overlayWidget: DraggablePreview(
                  previewFrame: null, // Not needed in overlay mode
                  videoSize: _videoSize,
                  textItems: _textItems,
                  imageItems: _imageItems,
                  currentPosition: _currentPosition,
                  colorGrade: _colorSettings,
                  onTextItemUpdated: _updateTextItem,
                  onImageItemUpdated: _updateImageItem,
                  onItemSelected: (id) {
                    if (!_isDisposed) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedItemId = id);
                      });
                    }
                  },
                  onItemDeleted: (id) {
                    if (!_isDisposed) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _deleteItem(id);
                      });
                    }
                  },
                  selectedItemId: _selectedItemId,
                  isPlaying: _isPlaying,
                  isOverlayMode: true, // ✅ Enable overlay mode
                ),
              ),
            ),
          ),
        ),

        // Mini timeline
        Container(
          height: isVeryCompact ? 50 : 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildMiniTimeline(isVeryCompact),
        ),

        SizedBox(height: isVeryCompact ? 4 : 8),

        // Quick actions
        if (!isVeryCompact) _buildQuickActions(isVeryCompact),
      ],
    );
  }

  Widget _buildMiniTimeline(bool isVeryCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Scrubber
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isDisposed) return;
                    try {
                      final percent = (details.localPosition.dx / width).clamp(
                        0.0,
                        1.0,
                      );
                      final position = Duration(
                        milliseconds:
                            (percent * widget.videoDuration.inMilliseconds)
                                .round(),
                      );

                      setState(() => _currentPosition = position);
                      _loadPreviewFrameDebounced();
                    } catch (e) {
                      debugPrint('❌ Scrub error: $e');
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          // Thumbnails
                          if (_thumbnails.isNotEmpty)
                            Row(
                              children: _thumbnails.map((thumb) {
                                return Expanded(
                                  child: Image.memory(
                                    thumb,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                );
                              }).toList(),
                            ),

                          // Trim overlay
                          Positioned.fill(
                            child: Row(
                              children: [
                                Container(
                                  width: width * _trimStartPercent,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                                const Spacer(),
                                Container(
                                  width: width * (1 - _trimEndPercent),
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),

                          // Playhead
                          Positioned(
                            left:
                                width *
                                (_currentPosition.inMilliseconds /
                                    widget.videoDuration.inMilliseconds.clamp(
                                      1,
                                      double.infinity,
                                    )),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: Colors.red,
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Time display
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: isVeryCompact ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVeryCompact ? 9 : 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _formatDuration(widget.videoDuration),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isVeryCompact ? 9 : 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(bool isVeryCompact) {
    final buttonSize = isVeryCompact ? 32.0 : 42.0;
    final iconSize = isVeryCompact ? 16.0 : 20.0;

    return Container(
      height: isVeryCompact ? 45 : 55,
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
    return Flexible(
      child: GestureDetector(
        onTap: () {
          if (!_isDisposed) {
            onTap();
            HapticFeedback.selectionClick();
          }
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
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            if (!isVeryCompact) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: Colors.white70, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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
        if (!isVeryCompact)
          Container(
            height: isCompact ? 80 : 100,
            margin: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DraggablePreview(
                previewFrame: _previewFrame,
                videoSize: _videoSize,
                textItems: _textItems,
                imageItems: _imageItems,
                currentPosition: _currentPosition,
                colorGrade: _colorSettings,
                onTextItemUpdated: _updateTextItem,
                onImageItemUpdated: _updateImageItem,
                onItemSelected: (id) {
                  if (!_isDisposed) {
                    setState(() => _selectedItemId = id);
                  }
                },
                onItemDeleted: (id) {
                  if (!_isDisposed) {
                    _deleteItem(id);
                  }
                },
                selectedItemId: _selectedItemId,
                isPlaying: _isPlaying,
                onPlayPause: _togglePlayback,
              ),
            ),
          ),

        // Unified timeline
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: UnifiedTimeline(
              totalDuration: widget.videoDuration,
              currentPosition: _currentPosition,
              textItems: _textItems,
              imageItems: _imageItems,
              audioItems: _audioItems,
              videoThumbnails: _thumbnails,
              onPositionChanged: (pos) {
                if (!_isDisposed) {
                  setState(() => _currentPosition = pos);
                  _loadPreviewFrameDebounced();
                }
              },
              onTextItemsChanged: (items) {
                if (_isDisposed) return;
                final previousState = _getCurrentState();
                setState(() => _textItems = List.from(items));
                _recordAction('text_timeline_change', previousState);
              },
              onImageItemsChanged: (items) {
                if (_isDisposed) return;
                final previousState = _getCurrentState();
                setState(() => _imageItems = List.from(items));
                _recordAction('image_timeline_change', previousState);
              },
              onAudioItemsChanged: (items) {
                if (_isDisposed) return;
                final previousState = _getCurrentState();
                setState(() => _audioItems = List.from(items));
                _recordAction('audio_timeline_change', previousState);
              },
              onItemSelected: (item) {
                if (!_isDisposed) {
                  setState(() => _selectedItemId = item?.id);
                }
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip to start
            _buildControlButton(
              icon: Icons.skip_previous,
              onTap: () {
                if (!_isDisposed) {
                  setState(() => _currentPosition = _trimStart);
                  _loadPreviewFrame();
                }
              },
              size: iconSize,
            ),

            // Rewind 5s
            _buildControlButton(
              icon: Icons.replay_5,
              onTap: () {
                if (_isDisposed) return;
                final newPos = _currentPosition - const Duration(seconds: 5);
                setState(() {
                  _currentPosition = newPos < _trimStart ? _trimStart : newPos;
                });
                _loadPreviewFrame();
              },
              size: iconSize,
            ),

            const SizedBox(width: 8),

            // Play/pause button
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: playIconSize,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Forward 5s
            _buildControlButton(
              icon: Icons.forward_5,
              onTap: () {
                if (_isDisposed) return;
                final newPos = _currentPosition + const Duration(seconds: 5);
                setState(() {
                  _currentPosition = newPos > _trimEnd ? _trimEnd : newPos;
                });
                _loadPreviewFrame();
              },
              size: iconSize,
            ),

            // Skip to end
            _buildControlButton(
              icon: Icons.skip_next,
              onTap: () {
                if (!_isDisposed) {
                  setState(() => _currentPosition = _trimEnd);
                  _loadPreviewFrame();
                }
              },
              size: iconSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return IconButton(
      onPressed: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, color: Colors.white70, size: size),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TABS MODE
  // ═══════════════════════════════════════════════════════

  Widget _buildTabsMode(bool isCompact, bool isVeryCompact) {
    return Column(
      children: [
        // Small preview (only if not very compact)
        if (!isVeryCompact)
          Container(
            height: isCompact ? 80 : 100,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _previewFrame != null
                  ? ColorFiltered(
                      colorFilter: _buildColorFilter(_colorSettings),
                      child: Image.memory(
                        _previewFrame!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.red,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelPadding: EdgeInsets.symmetric(horizontal: isVeryCompact ? 8 : 12),
        labelStyle: TextStyle(fontSize: isVeryCompact ? 9 : 10),
        dividerColor: Colors.transparent,
        tabs: _tabData.map((data) {
          return Tab(
            icon: Icon(data.$1, size: isVeryCompact ? 14 : 16),
            iconMargin: EdgeInsets.zero,
            height: isVeryCompact ? 32 : 36,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(bool isVeryCompact) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Trim Tab
        _buildSafeTab(
          () => TrimTab(
            videoPath: widget.videoPath,
            videoDuration: widget.videoDuration,
            thumbnails: _thumbnails,
            trimStartPercent: _trimStartPercent,
            trimEndPercent: _trimEndPercent,
            onTrimChanged: (start, end) {
              if (_isDisposed) return;
              final previousState = _getCurrentState();
              setState(() {
                _trimStartPercent = start.clamp(0.0, 1.0);
                _trimEndPercent = end.clamp(0.0, 1.0);
              });
              _recordAction('trim_change', previousState);
              _loadPreviewFrameDebounced();
            },
          ),
        ),

        // Color Tab
        _buildSafeTab(
          () => ColorTab(
            settings: _colorSettings,
            onSettingsChanged: (settings) {
              if (_isDisposed) return;
              final previousState = _getCurrentState();
              setState(() => _colorSettings = settings);
              _recordAction('color_change', previousState);
            },
          ),
        ),

        // Text Tab
        _buildSafeTab(
          () => TextTab(
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
              if (_isDisposed) return;
              final previousState = _getCurrentState();
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
            },
            videoDuration: widget.videoDuration,
          ),
        ),

        // Music Tab
        _buildSafeTab(
          () => MusicTab(
            selectedMusicPath: _selectedMusicPath,
            onMusicChanged: (path) {
              if (_isDisposed) return;
              final previousState = _getCurrentState();
              setState(() => _selectedMusicPath = path);
              _recordAction('music_change', previousState);
            },
            onMusicSelected: (track) {
              if (_isDisposed) return;
              setState(() => _selectedMusicTrack = track);
              if (track.localPath != null) {
                _addAudioTrack(track);
              }
            },
          ),
        ),

        // Image Tab
        _buildSafeTab(
          () => ImageTab(
            selectedImages: _selectedImages,
            onImagesChanged: (images) {
              if (!_isDisposed) {
                setState(() => _selectedImages = List.from(images));
              }
            },
            onImageSelected: (image) {
              if (!_isDisposed) {
                _addImageOverlay(image);
              }
            },
          ),
        ),

        // AI Tab
        _buildSafeTab(
          () => AiTab(
            onImageGenerated: (imageItem) {
              if (_isDisposed) return;
              final previousState = _getCurrentState();
              setState(() => _imageItems.add(imageItem));
              _recordAction('ai_image_add', previousState);
            },
            videoDuration: widget.videoDuration,
            currentPosition: _currentPosition,
          ),
        ),

        // Merge Tab
        _buildSafeTab(
          () => MergeTab(
            mergeQueue: _mergeQueue,
            onQueueChanged: (queue) {
              if (!_isDisposed) {
                setState(() => _mergeQueue = List.from(queue));
              }
            },
            onAddVideo: _pickVideoForMerge,
            onAddImage: _pickImageForMerge,
          ),
        ),

        // Audio Tab
        _buildSafeTab(
          () => AudioTab(
            attachedAudioPath: _attachedAudioPath,
            onAudioChanged: (path) {
              if (_isDisposed) return;
              final previousState = _getCurrentState();
              setState(() => _attachedAudioPath = path);
              _recordAction('audio_change', previousState);
            },
            onExtractAudio: _extractAudio,
          ),
        ),

        // Export Tab
        _buildSafeTab(
          () => ExportTab(
            selectedPreset: _selectedPreset,
            onPresetChanged: (preset) {
              if (!_isDisposed) {
                setState(() => _selectedPreset = preset);
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
        ),

        // Library Tab
        _buildSafeTab(
          () => LibraryTab(
            items: _libraryItems,
            onRefresh: _loadLibrary,
            onDelete: _deleteLibraryItem,
            onRename: _renameLibraryItem,
            onShare: _shareLibraryItem,
            onEdit: _editLibraryItem,
          ),
        ),
      ],
    );
  }

  Widget _buildSafeTab(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      debugPrint('❌ Build tab error: $e');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading tab',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PART 3 - BOTTOM BAR, DIALOGS, ACTIONS & SMOOTH PLAYBACK
  // ═══════════════════════════════════════════════════════

  // Continue _VideoEditorSheetState class:

  Widget _buildBottomBar(bool isVeryCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isVeryCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
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
                    width: _hasUnsavedChanges ? 2 : 1,
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
                  onPressed: _isProcessing ? null : _exportVideo,
                  icon: Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.upload,
                    size: isVeryCompact ? 14 : 16,
                  ),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Export',
                    style: TextStyle(
                      fontSize: isVeryCompact ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProcessing ? Colors.grey : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _processProgress > 0 ? _processProgress : null,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                      if (_processProgress > 0)
                        Text(
                          '${(_processProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _processMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_processProgress > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 4,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _processProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    try {
                      _editService.cancelCurrentOperation();
                      setState(() {
                        _isProcessing = false;
                        _processProgress = 0;
                        _processMessage = '';
                      });
                    } catch (e) {
                      debugPrint('❌ Cancel processing error: $e');
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTION HANDLERS
  // ═══════════════════════════════════════════════════════

  void _addTextOverlay() {
    if (_isDisposed) return;

    final previousState = _getCurrentState();

    try {
      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newItem = TextTimelineItem.create(
        text: 'New Text',
        startTime: _currentPosition,
        endTime: _currentPosition + defaultDuration,
        x: 0.5,
        y: 0.8,
      );

      setState(() {
        _textItems.add(newItem);
        _selectedItemId = newItem.id;
      });

      _recordAction('add_text', previousState);
      HapticFeedback.mediumImpact();
      _showSuccess('Text added');
    } catch (e) {
      debugPrint('❌ Add text overlay error: $e');
      _showError('Failed to add text');
    }
  }

  void _addImageOverlay(StockImage image) {
    if (_isDisposed) return;

    final previousState = _getCurrentState();

    try {
      if (image.localPath == null && image.fullUrl.isEmpty) {
        _showError('Invalid image');
        return;
      }

      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newItem = ImageTimelineItem.create(
        imagePath: image.localPath ?? image.fullUrl,
        startTime: _currentPosition,
        endTime: _currentPosition + defaultDuration,
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
      _showSuccess('Image added');
    } catch (e) {
      debugPrint('❌ Add image overlay error: $e');
      _showError('Failed to add image');
    }
  }

  void _addAudioTrack(MusicTrack track) {
    if (_isDisposed) return;

    final previousState = _getCurrentState();

    try {
      if (track.localPath == null) {
        _showError('Audio not downloaded');
        return;
      }

      final newItem = AudioTimelineItem.create(
        audioPath: track.localPath!,
        startTime: Duration.zero,
        endTime: track.duration < widget.videoDuration
            ? track.duration
            : widget.videoDuration,
        audioDuration: track.duration,
        title: track.title,
        artist: track.artist,
      );

      setState(() => _audioItems.add(newItem));
      _recordAction('add_audio', previousState);
      HapticFeedback.mediumImpact();
      _showSuccess('Audio added');
    } catch (e) {
      debugPrint('❌ Add audio track error: $e');
      _showError('Failed to add audio');
    }
  }

  void _updateTextItem(TextTimelineItem item) {
    if (_isDisposed) return;

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
    if (_isDisposed) return;

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

  void _deleteItem(String itemId) {
    if (_isDisposed || itemId.isEmpty) return;

    final previousState = _getCurrentState();

    try {
      setState(() {
        _textItems.removeWhere((item) => item.id == itemId);
        _imageItems.removeWhere((item) => item.id == itemId);
        _audioItems.removeWhere((item) => item.id == itemId);
        if (_selectedItemId == itemId) {
          _selectedItemId = null;
        }
      });

      _recordAction('delete_item', previousState);
      HapticFeedback.mediumImpact();
      _showSuccess('Item deleted');
    } catch (e) {
      debugPrint('❌ Delete item error: $e');
    }
  }

  TextPositionCustom _getPositionFromXY(double x, double y) {
    try {
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
    } catch (e) {
      return TextPositionCustom.center;
    }
  }

  Future<void> _exportVideo() async {
    if (_isProcessing || _isDisposed) return;

    // Save project before export
    await _saveProject();

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Preparing export...';
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
          if (!_isDisposed && mounted) {
            setState(() {
              _processProgress = progress.progress;
              _processMessage = progress.message;
            });
          }
        },
      );

      if (result != null && mounted) {
        _showSuccess('Exported successfully!');
        widget.onExportComplete?.call(result);
        await _loadLibrary();
      } else if (mounted) {
        _showError('Export failed');
      }
    } catch (e) {
      debugPrint('❌ Export error: $e');
      if (mounted) _showError('Export error: ${e.toString()}');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _extractAudio() async {
    if (_isProcessing || _isDisposed) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Extracting audio...';
    });

    try {
      final result = await _editService.extractAudio(
        inputPath: widget.videoPath,
        onProgress: (p) {
          if (!_isDisposed && mounted) {
            setState(() => _processProgress = p);
          }
        },
      );

      if (result != null && mounted) {
        _showSuccess('Audio extracted!');
        await _loadLibrary();
      } else if (mounted) {
        _showError('Extraction failed');
      }
    } catch (e) {
      debugPrint('❌ Extract audio error: $e');
      if (mounted) _showError('Error: ${e.toString()}');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _pickVideoForMerge() {
    if (_isDisposed) return;
    HapticFeedback.selectionClick();
    _showInfo('Video picker coming soon');
  }

  void _pickImageForMerge() {
    if (_isDisposed) return;
    HapticFeedback.selectionClick();
    _showInfo('Image picker coming soon');
  }

  void _showExportOptionsDialog() {
    if (_isDisposed) return;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
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
                        if (!_isDisposed) {
                          setState(() => _selectedPreset = preset);
                        }
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Future<void> _deleteLibraryItem(MediaItem item) async {
    if (_isDisposed) return;

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

      if (confirmed == true && mounted) {
        await _editService.deleteFile(item.path);
        await _loadLibrary();
        _showSuccess('Deleted');
      }
    } catch (e) {
      debugPrint('❌ Delete library item error: $e');
      _showError('Delete failed');
    }
  }

  Future<void> _renameLibraryItem(MediaItem item) async {
    if (_isDisposed) return;

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

      if (newName != null &&
          newName.isNotEmpty &&
          newName != item.name &&
          mounted) {
        await _editService.renameFile(item.path, newName);
        await _loadLibrary();
        _showSuccess('Renamed');
      }
    } catch (e) {
      debugPrint('❌ Rename library item error: $e');
      _showError('Rename failed');
    }
  }

  Future<void> _shareLibraryItem(MediaItem item) async {
    if (_isDisposed) return;

    try {
      await _editService.shareFile(item.path);
    } catch (e) {
      debugPrint('❌ Share library item error: $e');
      _showError('Share failed');
    }
  }

  void _editLibraryItem(MediaItem item) {
    if (_isDisposed) return;
    HapticFeedback.selectionClick();
    _showInfo('Edit feature coming soon');
  }

  String _formatDate(DateTime date) {
    try {
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DIALOG WIDGETS
// ═══════════════════════════════════════════════════════

class _RenameDialog extends StatelessWidget {
  final TextEditingController controller;

  const _RenameDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Rename', style: TextStyle(color: Colors.white)),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String projectName;

  const _DeleteConfirmDialog({required this.projectName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Delete Project?',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Are you sure you want to delete "$projectName"?\nThis action cannot be undone.',
        style: TextStyle(color: Colors.grey[400]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _ResetConfirmDialog extends StatelessWidget {
  const _ResetConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Reset All?', style: TextStyle(color: Colors.white)),
      content: Text(
        'This will reset all edits. Are you sure?',
        style: TextStyle(color: Colors.grey[400]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reset', style: TextStyle(color: Colors.orange)),
        ),
      ],
    );
  }
}

class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text('Discard', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'save'),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectsSheet extends StatelessWidget {
  final List<EditorProjectData> projects;
  final String? currentProjectId;
  final VoidCallback onRefresh;
  final Function(EditorProjectData) onOpen;
  final Function(EditorProjectData) onRename;
  final Function(EditorProjectData) onDelete;

  const _ProjectsSheet({
    required this.projects,
    required this.currentProjectId,
    required this.onRefresh,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
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

            // Header
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
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Projects list
            Flexible(
              child: projects.isEmpty
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
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final isCurrentProject = project.id == currentProjectId;

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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white54,
                              ),
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
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white54,
                              ),
                              color: Colors.grey[850],
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_open,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Open',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Rename',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'open':
                                    onOpen(project);
                                    break;
                                  case 'rename':
                                    onRename(project);
                                    break;
                                  case 'delete':
                                    onDelete(project);
                                    break;
                                }
                              },
                            ),
                            onTap: () => onOpen(project),
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

  String _formatDate(DateTime date) {
    try {
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DIALOG WIDGETS (Extract for reusability)
// ═══════════════════════════════════════════════════════

class _SaveAsDialog extends StatelessWidget {
  final TextEditingController controller;

  const _SaveAsDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

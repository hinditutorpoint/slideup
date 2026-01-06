import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/utils/safe_async.dart';
import '../utils/reader_utils.dart';

import '../../txt_reader/screens/txt_reader_screen.dart';
import '../../epub_reader/downloaded_epub_catalogue.dart';
import '../providers/sf_thumbnail_manager.dart';

// ========== Configuration ==========

class ReaderConfig {
  const ReaderConfig._();

  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Duration positionSaveDebounce = Duration(seconds: 2);
  static const Duration gestureCooldown = Duration(milliseconds: 300);
  static const Duration zoomRestoreDelay = Duration(milliseconds: 200);

  static const double minZoom = 0.5;
  static const double maxZoom = 4.0;
  static const double zoomStep = 0.25;

  static const double tapThreshold = 12.0;
  static const double swipeThreshold = 60.0;
  static const double swipeVelocityThreshold = 200.0;
  static const double panThreshold = 15.0;
  static const double zoomThresholdForSwipe = 1.02;

  static const double fitWidthZoom = 1.0;
  static const double fitHeightZoom = 0.7;
}

// ========== Enums ==========

enum FitMode { fitWidth, fitHeight, custom }

enum GestureState { idle, tapping, panning, zooming, swiping }

// ========== CUSTOM FLIP WIDGET (Paint-phase only, no layout issues) ==========

/// A widget that flips its child horizontally and/or vertically.
/// Unlike Transform, this applies the flip only during paint phase,
/// avoiding layout conflicts with widgets like SfPdfViewer.
// ========== CUSTOM FLIP WIDGET (SAFE) ==========

class FlipWidget extends SingleChildRenderObjectWidget {
  final bool flipX;
  final bool flipY;

  const FlipWidget({
    super.key,
    super.child,
    this.flipX = false,
    this.flipY = false,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderFlip(flipX: flipX, flipY: flipY);
  }

  @override
  void updateRenderObject(BuildContext context, RenderFlip renderObject) {
    renderObject
      ..flipX = flipX
      ..flipY = flipY;
  }
}

class RenderFlip extends RenderProxyBox {
  RenderFlip({bool flipX = false, bool flipY = false})
    : _flipX = flipX,
      _flipY = flipY;

  bool _flipX;
  bool get flipX => _flipX;
  set flipX(bool value) {
    if (_flipX == value) return;
    _flipX = value;
    markNeedsPaint();
  }

  bool _flipY;
  bool get flipY => _flipY;
  set flipY(bool value) {
    if (_flipY == value) return;
    _flipY = value;
    markNeedsPaint();
  }

  Matrix4 _paintFlipTransform() {
    final w = size.width;
    final h = size.height;

    return Matrix4.identity()
      ..translate(w / 2, h / 2)
      ..scale(_flipX ? -1.0 : 1.0, _flipY ? -1.0 : 1.0, 1.0)
      ..translate(-w / 2, -h / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    if ((!_flipX && !_flipY) || !hasSize) {
      super.paint(context, offset);
      return;
    }

    context.pushTransform(
      needsCompositing,
      offset,
      _paintFlipTransform(),
      super.paint,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hasSize || (!_flipX && !_flipY)) {
      return super.hitTest(result, position: position);
    }

    final dx = _flipX ? (size.width - position.dx) : position.dx;
    final dy = _flipY ? (size.height - position.dy) : position.dy;

    return super.hitTest(result, position: Offset(dx, dy));
  }
}

// ========== INVERT COLORS WIDGET (For Dark Mode) ==========

/// A widget that inverts colors of its child for dark mode reading.
class InvertColors extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const InvertColors({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, // Red
        0, -1, 0, 0, 255, // Green
        0, 0, -1, 0, 255, // Blue
        0, 0, 0, 1, 0, // Alpha
      ]),
      child: child,
    );
  }
}

// ========== Main Widget ==========

class EnhancedPdfReader extends StatefulWidget {
  final String title;
  final String? identifier;
  final int? initialPage;
  final String? pdfUrl;
  final File? localFile;

  const EnhancedPdfReader({
    super.key,
    required this.title,
    this.identifier,
    this.initialPage,
    this.pdfUrl,
    this.localFile,
  }) : assert(pdfUrl != null || localFile != null);

  const EnhancedPdfReader.network({
    super.key,
    required String this.pdfUrl,
    required this.title,
    this.identifier,
    this.initialPage,
  }) : localFile = null;

  const EnhancedPdfReader.file({
    super.key,
    required File file,
    required this.title,
    this.identifier,
    this.initialPage,
  }) : localFile = file,
       pdfUrl = null;

  @override
  State<EnhancedPdfReader> createState() => _EnhancedPdfReaderState();
}

class _EnhancedPdfReaderState extends State<EnhancedPdfReader>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Controllers
  PdfViewerController? _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  late final AnimationController _controlsAnimController;
  late final Animation<double> _controlsFadeAnim;
  late final AnimationController _pageTransitionController;
  late Animation<double> _pageTransitionAnim;

  // State
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = false;
  bool _showPageGrid = false;
  bool _showSettings = false;

  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  double _prevZoomLevel = 1.0;
  double _sliderValue = 1.0;
  bool _isScrubbing = false;

  // Zoom Memory & Fit Mode
  FitMode _fitMode = FitMode.fitWidth;
  double _userZoomLevel = 1.0;
  bool _isRestoringZoom = false;
  Timer? _zoomRestoreTimer;
  int _zoomRestoreRetries = 0;

  // Flip & Dark Mode
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _darkModeEnabled = false;

  File? _pdfFile;
  double? _downloadProgress;
  CancelToken? _cancelToken;
  bool _didRestorePosition = false;

  bool _isAnimatingPageTransition = false;
  bool _pageTransitionForward = true;
  PageTransitionType _activeTransitionType = PageTransitionType.none;

  Timer? _savePositionTimer;

  // Managers
  final ReaderStorageManager _storageManager = ReaderStorageManager();
  final DownloadLibraryManager _libraryManager = DownloadLibraryManager();
  final ArchivePageThumbnailManager _thumbnailManager =
      ArchivePageThumbnailManager();
  late final DioPdfDownloader _downloader;

  ReaderSettings _settings = const ReaderSettings();

  // Gesture State
  GestureState _gestureState = GestureState.idle;
  int _activePointers = 0;
  Offset? _pointerDownPos;
  Offset? _lastPointerPos;
  DateTime? _pointerDownTime;
  DateTime? _lastGestureTime;
  bool _gestureConsumed = false;

  // Search
  PdfTextSearchResult? _searchResult;

  final SfThumbnailManager _sfThumbs = SfThumbnailManager();
  Uint8List? _thumbDocBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controlsAnimController = AnimationController(
      vsync: this,
      duration: ReaderConfig.animationDuration,
    );
    _controlsFadeAnim = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeOut,
    );

    _pageTransitionController = AnimationController(
      vsync: this,
      duration: ReaderConfig.pageTransitionDuration,
    );
    _pageTransitionAnim = CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeOutCubic,
    );
    _pageTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _isAnimatingPageTransition = false);
        _pageTransitionController.reset();
      }
    });

    _pdfController = PdfViewerController();
    _downloader = DioPdfDownloader();

    _initializeAndLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _savePositionNow();
    }
  }

  Future<RgbaThumb?> _getLocalThumb(int pageNumber) async {
    if (_pdfFile == null) return null;

    // Lazy load bytes once
    _thumbDocBytes ??= await _pdfFile!.readAsBytes();
    // Open renderer once for this document
    await _sfThumbs.open(bytes: _thumbDocBytes!, documentId: _docId);

    // Render thumb
    return await _sfThumbs.getThumb(pageNumber: pageNumber, thumbWidth: 200);
  }

  Future<void> _initializeAndLoad() async {
    final result = await SafeAsync.run(() async {
      await _storageManager.initialize();
      await _libraryManager.initialize();
      return await _storageManager.getSettings();
    }, operationName: 'Init');

    result.when(
      success: (settings) {
        if (mounted) {
          setState(() => _settings = settings);
          _applySettings(settings);
        }
        _loadPdfFile();
      },
      failure: (e, _) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Init failed: $e';
          });
        }
      },
    );
  }

  void _applySettings(ReaderSettings s) {
    _applyWakelock(s.keepScreenOn);
    _updateTransitionCurve(s.pageTransition);
  }

  void _applyWakelock(bool enable) {
    SafeAsync.run(() async {
      enable ? await WakelockPlus.enable() : await WakelockPlus.disable();
    });
  }

  void _updateTransitionCurve(PageTransitionType type) {
    final (curve, duration) = switch (type) {
      PageTransitionType.curl => (
        Curves.easeOutCubic,
        const Duration(milliseconds: 350),
      ),
      PageTransitionType.slide => (
        Curves.easeOutQuart,
        const Duration(milliseconds: 280),
      ),
      PageTransitionType.fade => (
        Curves.easeInOut,
        const Duration(milliseconds: 220),
      ),
      PageTransitionType.none => (Curves.linear, Duration.zero),
    };
    _pageTransitionController.duration = duration;
    _pageTransitionAnim = CurvedAnimation(
      parent: _pageTransitionController,
      curve: curve,
    );
  }

  Future<void> _loadPdfFile() async {
    if (!mounted) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _hasError = false;
      _downloadProgress = null;
      _pdfFile = null;
    });

    final result = await SafeAsync.run<File>(() async {
      if (widget.localFile != null) {
        final f = widget.localFile!;
        if (!await f.exists() || await f.length() == 0) {
          throw Exception('Invalid file');
        }
        return f;
      }

      final url = DocumentDownloadManager.normalizeArchiveUrl(widget.pdfUrl!);

      final existing = await _libraryManager.getItemByUrl(url);
      if (existing != null) {
        final file = await _libraryManager.getFileForItem(existing);
        if (await file.exists() && await file.length() > 0) {
          await _libraryManager.markOpened(existing.id);
          return file;
        }
      }

      final item = await _libraryManager.downloadAndSave(
        url: url,
        title: widget.title,
        downloader: _downloader,
        cancelToken: _cancelToken!,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
        thumbnailUrl: widget.identifier != null
            ? 'https://archive.org/services/img/${widget.identifier}'
            : null,
      );

      return await _libraryManager.getFileForItem(item);
    }, operationName: 'Load PDF');

    if (!mounted) return;

    result.fold(
      success: (file) => _handleFileLoaded(file),
      failure: (e, _) {
        if (e is DioException && e.type == DioExceptionType.cancel) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      },
    );

    SafeAsync.run(() async {
      _thumbDocBytes = null;
      await _sfThumbs.close();
    });
  }

  void _handleFileLoaded(File file) {
    final ext = file.path.toLowerCase();

    if (ext.endsWith('.epub')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DownloadedEpubCatalogue(
            localFilePath: file.path,
            bookTitle: widget.title,
          ),
        ),
      );
      return;
    }

    if (ext.endsWith('.txt')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TxtReaderScreen(txtUrl: file.path, title: widget.title),
        ),
      );
      return;
    }

    setState(() {
      _pdfFile = file;
      _isLoading = false;
    });
  }

  String get _docId =>
      widget.identifier ?? widget.pdfUrl ?? _pdfFile?.path ?? widget.title;

  // ========== Position ==========

  Future<void> _restorePosition() async {
    if (_totalPages <= 0) return;

    final result = await SafeAsync.run(
      () => _storageManager.getReadingPosition(_docId),
    );
    result.when(
      success: (pos) {
        int? target;
        if (pos != null && pos.page >= 1 && pos.page <= _totalPages) {
          target = pos.page;
        } else if (widget.initialPage != null && widget.initialPage! >= 1) {
          target = widget.initialPage!.clamp(1, _totalPages);
        }
        if (target != null && target > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _jumpToPage(target!);
          });
        }
      },
      failure: (_, __) {},
    );
  }

  void _savePositionNow() {
    if (_totalPages <= 0) return;
    SafeAsync.run(
      () => _storageManager.saveReadingPosition(
        ReadingPosition(
          identifier: _docId,
          page: _currentPage,
          progress: _currentPage / _totalPages,
          metadata: {'title': widget.title},
        ),
      ),
    );
  }

  void _scheduleSavePosition() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(
      ReaderConfig.positionSaveDebounce,
      _savePositionNow,
    );
  }

  // ========== PDF Callbacks ==========

  void _onDocumentLoaded(PdfDocumentLoadedDetails d) {
    if (!mounted) return;
    setState(() {
      _totalPages = d.document.pages.count;
      _isLoading = false;
      _sliderValue = _currentPage.toDouble();
    });
    if (!_didRestorePosition) {
      _didRestorePosition = true;
      _restorePosition();
    }
    _showControlsBriefly();
  }

  void _showControlsBriefly() {
    _showControlsNow();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_showPageGrid && !_showSettings) {
        _hideControls();
      }
    });
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails d) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = d.description;
      _isLoading = false;
    });
  }

  void _onPageChanged(PdfPageChangedDetails d) {
    if (!mounted) return;
    setState(() {
      _currentPage = d.newPageNumber;
      if (!_isScrubbing) _sliderValue = _currentPage.toDouble();
    });
    _scheduleSavePosition();
    _scheduleZoomRestore();
  }

  void _onZoomLevelChanged(PdfZoomDetails d) {
    if (!mounted) return;
    _prevZoomLevel = _zoomLevel;
    setState(() => _zoomLevel = d.newZoomLevel);

    if (!_isRestoringZoom) {
      _userZoomLevel = d.newZoomLevel;
      _updateFitModeFromZoom(d.newZoomLevel);
    }

    if ((_zoomLevel - _prevZoomLevel).abs() > 0.05) {
      _gestureState = GestureState.zooming;
      _gestureConsumed = true;
    }
  }

  // ========== ZOOM MEMORY SYSTEM ==========

  void _scheduleZoomRestore() {
    _zoomRestoreTimer?.cancel();
    _zoomRestoreRetries = 0;
    _attemptZoomRestore();
  }

  void _attemptZoomRestore() {
    if (!mounted || _pdfController == null) return;

    _zoomRestoreTimer = Timer(ReaderConfig.zoomRestoreDelay, () {
      if (!mounted || _pdfController == null) return;

      final currentZoom = _pdfController!.zoomLevel;
      final targetZoom = _userZoomLevel;

      if ((targetZoom - currentZoom).abs() > 0.02) {
        _isRestoringZoom = true;

        SafeAsync.run(() async {
          if (_pdfController != null) {
            _pdfController!.zoomLevel = targetZoom;
          }
        });

        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted || _pdfController == null) return;

          final newZoom = _pdfController!.zoomLevel;
          if ((targetZoom - newZoom).abs() > 0.02 && _zoomRestoreRetries < 3) {
            _zoomRestoreRetries++;
            _attemptZoomRestore();
          } else {
            _isRestoringZoom = false;
          }
        });
      }
    });
  }

  void _updateFitModeFromZoom(double zoom) {
    if ((zoom - ReaderConfig.fitWidthZoom).abs() < 0.05) {
      _fitMode = FitMode.fitWidth;
    } else if ((zoom - ReaderConfig.fitHeightZoom).abs() < 0.05) {
      _fitMode = FitMode.fitHeight;
    } else {
      _fitMode = FitMode.custom;
    }
    if (mounted) setState(() {});
  }

  // ========== FIT MODE ==========

  void _setFitWidth() {
    _fitMode = FitMode.fitWidth;
    _userZoomLevel = ReaderConfig.fitWidthZoom;
    _applyZoomSafely(ReaderConfig.fitWidthZoom);
    setState(() {});
  }

  void _setFitHeight() {
    _fitMode = FitMode.fitHeight;
    _userZoomLevel = ReaderConfig.fitHeightZoom;
    _applyZoomSafely(ReaderConfig.fitHeightZoom);
    setState(() {});
  }

  void _toggleFitMode() {
    if (_fitMode == FitMode.fitWidth) {
      _setFitHeight();
    } else {
      _setFitWidth();
    }
  }

  void _applyZoomSafely(double zoom) {
    SafeAsync.run(() async {
      if (_pdfController != null) {
        _isRestoringZoom = true;
        _pdfController!.zoomLevel = zoom.clamp(
          ReaderConfig.minZoom,
          ReaderConfig.maxZoom,
        );
        await Future.delayed(const Duration(milliseconds: 100));
        _isRestoringZoom = false;
      }
    });
  }

  // ========== FLIP CONTROLS ==========

  void _toggleFlipHorizontal() {
    if (mounted) {
      setState(() => _flipHorizontal = !_flipHorizontal);
    }
  }

  void _toggleFlipVertical() {
    if (mounted) {
      setState(() => _flipVertical = !_flipVertical);
    }
  }

  void _resetFlip() {
    if (mounted) {
      setState(() {
        _flipHorizontal = false;
        _flipVertical = false;
      });
    }
  }

  // ========== DARK MODE ==========

  void _toggleDarkMode() {
    if (mounted) {
      setState(() => _darkModeEnabled = !_darkModeEnabled);
    }
  }

  // ========== Navigation ==========

  void _jumpToPage(int page) {
    if (_pdfController == null || _totalPages <= 0) return;
    _pdfController!.jumpToPage(page.clamp(1, _totalPages));
  }

  void _goNext() {
    if (_currentPage >= _totalPages || !_canNavigate()) return;
    _triggerTransition(forward: true);
    _jumpToPage(_currentPage + 1);
    _markGestureTime();
  }

  void _goPrev() {
    if (_currentPage <= 1 || !_canNavigate()) return;
    _triggerTransition(forward: false);
    _jumpToPage(_currentPage - 1);
    _markGestureTime();
  }

  bool _canNavigate() {
    if (_zoomLevel > ReaderConfig.zoomThresholdForSwipe) return false;
    if (_gestureState == GestureState.panning) return false;
    if (_gestureState == GestureState.zooming) return false;
    if (_lastGestureTime != null) {
      if (DateTime.now().difference(_lastGestureTime!) <
          ReaderConfig.gestureCooldown) {
        return false;
      }
    }
    return true;
  }

  void _markGestureTime() {
    _lastGestureTime = DateTime.now();
  }

  void _triggerTransition({required bool forward}) {
    if (_settings.pageTransition == PageTransitionType.none) return;
    if (_settings.pageTransition == PageTransitionType.curl &&
        !_settings.enablePageCurl) {
      return;
    }

    setState(() {
      _isAnimatingPageTransition = true;
      _pageTransitionForward = forward;
      _activeTransitionType = _settings.pageTransition;
    });
    _pageTransitionController.forward();
  }

  // ========== Controls ==========

  void _showControlsNow() {
    if (_showControls) return;
    setState(() => _showControls = true);
    _controlsAnimController.forward();
  }

  void _hideControls() {
    if (!_showControls) return;
    _controlsAnimController.reverse().then((_) {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePageGrid() => setState(() => _showPageGrid = !_showPageGrid);
  void _toggleSettings() => setState(() => _showSettings = !_showSettings);

  // ========== Gesture Handling ==========

  void _onPointerDown(PointerDownEvent e) {
    _activePointers++;

    if (_activePointers == 1) {
      _pointerDownPos = e.position;
      _lastPointerPos = e.position;
      _pointerDownTime = DateTime.now();
      _gestureState = GestureState.tapping;
      _gestureConsumed = false;
    } else if (_activePointers >= 2) {
      _gestureState = GestureState.zooming;
      _gestureConsumed = true;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_gestureConsumed || _activePointers >= 2) {
      return;
    }

    if (_pointerDownPos == null) return;

    final delta = e.position - _pointerDownPos!;
    final distance = delta.distance;

    _lastPointerPos = e.position;

    if (_zoomLevel > ReaderConfig.zoomThresholdForSwipe) {
      if (distance > ReaderConfig.panThreshold) {
        _gestureState = GestureState.panning;
        _gestureConsumed = true;
      }
    } else {
      if (distance > ReaderConfig.panThreshold &&
          distance < ReaderConfig.swipeThreshold) {
        _gestureState = GestureState.swiping;
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers = math.max(0, _activePointers - 1);

    if (_activePointers > 0) return;

    if (!_gestureConsumed &&
        _pointerDownPos != null &&
        _lastPointerPos != null) {
      final delta = _lastPointerPos! - _pointerDownPos!;
      final distance = delta.distance;
      final duration = DateTime.now().difference(_pointerDownTime!);
      final velocity = duration.inMilliseconds > 0
          ? distance / duration.inMilliseconds * 1000
          : 0.0;

      if (distance < ReaderConfig.tapThreshold &&
          duration.inMilliseconds < 250) {
        _handleTap(e.position);
      } else if (_settings.enableSwipeNavigation &&
          _zoomLevel <= ReaderConfig.zoomThresholdForSwipe &&
          _gestureState != GestureState.panning &&
          _gestureState != GestureState.zooming) {
        if (distance > ReaderConfig.swipeThreshold ||
            velocity > ReaderConfig.swipeVelocityThreshold) {
          _handleSwipe(delta);
        }
      }
    }

    _resetGesture();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) _resetGesture();
  }

  void _resetGesture() {
    _pointerDownPos = null;
    _lastPointerPos = null;
    _pointerDownTime = null;
    _gestureState = GestureState.idle;
    _gestureConsumed = false;
  }

  void _handleTap(Offset pos) {
    if (!_showControls) {
      _showControlsNow();
      return;
    }

    final size = MediaQuery.of(context).size;
    final topBarH = MediaQuery.of(context).padding.top + 56;
    final bottomBarH = 120.0;
    final gridW = _showPageGrid ? 220.0 : 0.0;

    final inTop = pos.dy < topBarH;
    final inBottom = pos.dy > size.height - bottomBarH;
    final inGrid = pos.dx > size.width - gridW;

    if (!inTop && !inBottom && !inGrid) {
      _hideControls();
    }
  }

  void _handleSwipe(Offset delta) {
    double swipeDist = 0;

    if (_settings.swipeDirection == SwipeDirection.horizontal) {
      swipeDist = delta.dx;
    } else if (_settings.swipeDirection == SwipeDirection.vertical) {
      swipeDist = delta.dy;
    } else {
      swipeDist = delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy;
    }

    if (swipeDist > ReaderConfig.swipeThreshold) {
      _goPrev();
    } else if (swipeDist < -ReaderConfig.swipeThreshold) {
      _goNext();
    }
  }

  // ========== Zoom ==========

  void _zoomIn() {
    final newZoom = (_zoomLevel + ReaderConfig.zoomStep).clamp(
      ReaderConfig.minZoom,
      ReaderConfig.maxZoom,
    );
    _userZoomLevel = newZoom;
    _pdfController?.zoomLevel = newZoom;
  }

  void _zoomOut() {
    final newZoom = (_zoomLevel - ReaderConfig.zoomStep).clamp(
      ReaderConfig.minZoom,
      ReaderConfig.maxZoom,
    );
    _userZoomLevel = newZoom;
    _pdfController?.zoomLevel = newZoom;
  }

  void _resetZoom() {
    _userZoomLevel = 1.0;
    _pdfController?.zoomLevel = 1.0;
    _fitMode = FitMode.fitWidth;
    setState(() {});
  }

  // ========== Actions ==========

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => PdfSearchDialog(
        onSearch: (q) => _searchResult = _pdfController?.searchText(q),
        onClear: () {
          _pdfController?.clearSelection();
          _searchResult = null;
        },
        onNext: () => _searchResult?.nextInstance(),
        onPrev: () => _searchResult?.previousInstance(),
      ),
    );
  }

  void _showGoToDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: '1 - $_totalPages'),
          onSubmitted: (v) {
            Navigator.pop(context);
            _goToPage(v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goToPage(ctrl.text);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _goToPage(String text) {
    final p = int.tryParse(text);
    if (p != null && p >= 1 && p <= _totalPages) {
      _jumpToPage(p);
    } else {
      _showSnack('Invalid page');
    }
  }

  Future<void> _addBookmark() async {
    final result = await SafeAsync.run(
      () => _storageManager.addBookmark(
        Bookmark(
          identifier: _docId,
          page: _currentPage,
          title: 'Page $_currentPage',
        ),
      ),
    );
    result.when(
      success: (_) => _showSnack('Bookmark added'),
      failure: (_, __) => _showSnack('Failed'),
    );
  }

  void _showBookmarks() async {
    final result = await SafeAsync.run(
      () => _storageManager.getBookmarks(_docId),
    );
    if (!mounted) return;
    result.when(
      success: (list) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => BookmarksSheet(
            bookmarks: list,
            onTap: (b) {
              Navigator.pop(context);
              _jumpToPage(b.page);
            },
            onDelete: (b) => SafeAsync.run(
              () => _storageManager.removeBookmark(_docId, b.id),
            ),
          ),
        );
      },
      failure: (_, __) => _showSnack('Failed to load'),
    );
  }

  Future<void> _share() async {
    await SafeAsync.run(() async {
      if (_pdfFile != null && await _pdfFile!.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            title: widget.title,
            files: [XFile(_pdfFile!.path)],
            subject: widget.title,
          ),
        );
      } else if (widget.pdfUrl != null) {
        await SharePlus.instance.share(
          ShareParams(
            title: widget.title,
            text: widget.pdfUrl,
            subject: widget.title,
          ),
        );
      }
    });
  }

  Future<void> _saveOffline() async {
    if (_pdfFile == null) return;
    final result = await SafeAsync.run(
      () => _libraryManager.saveFromExistingFile(
        sourceFile: _pdfFile!,
        title: widget.title,
        sourceUrl: widget.pdfUrl,
      ),
    );
    result.when(
      success: (i) => _showSnack('Saved'),
      failure: (_, __) => _showSnack('Failed'),
    );
  }

  void _updateSettings(ReaderSettings s) {
    final old = _settings;
    setState(() => _settings = s);
    if (old.keepScreenOn != s.keepScreenOn) _applyWakelock(s.keepScreenOn);
    if (old.pageTransition != s.pageTransition) {
      _updateTransitionCurve(s.pageTransition);
      SafeAsync.run(() => _storageManager.saveSettings(s));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savePositionNow();
    _savePositionTimer?.cancel();
    _zoomRestoreTimer?.cancel();
    _cancelToken?.cancel();
    _downloader.dispose();
    _controlsAnimController.dispose();
    _pageTransitionController.dispose();
    _pdfController?.dispose();
    SafeAsync.run(() => WakelockPlus.disable());
    SafeAsync.run(() async => _sfThumbs.close());
    super.dispose();
  }

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildContent()),
          if (_isAnimatingPageTransition)
            Positioned.fill(child: _buildTransitionOverlay()),
          if (_showControls && !_isLoading && !_hasError) ...[
            _buildTopBar(),
            _buildBottomBar(),
          ],
          if (_showPageGrid) _buildPageGrid(),
          if (_showSettings) _buildSettingsPanel(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Color get _bgColor {
    if (_darkModeEnabled) return Colors.black;
    return switch (_settings.theme) {
      'light' => Colors.white,
      'sepia' => const Color(0xFFF5E6D3),
      _ => const Color(0xFF121212),
    };
  }

  // ========== FIXED: Using Custom FlipWidget ==========

  Widget _buildContent() {
    if (_hasError) return _buildError();
    if (_pdfFile == null) return _buildLoading();

    final scrollDir = _settings.swipeDirection == SwipeDirection.vertical
        ? PdfScrollDirection.vertical
        : PdfScrollDirection.horizontal;

    // Build the PDF viewer
    Widget pdfViewer = SfPdfViewer.file(
      _pdfFile!,
      key: _pdfViewerKey,
      controller: _pdfController,
      onDocumentLoaded: _onDocumentLoaded,
      onDocumentLoadFailed: _onDocumentLoadFailed,
      onPageChanged: _onPageChanged,
      onZoomLevelChanged: _onZoomLevelChanged,
      pageLayoutMode: PdfPageLayoutMode.single,
      scrollDirection: scrollDir,
      pageSpacing: 0,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      canShowPaginationDialog: false,
      enableDoubleTapZooming: true,
      maxZoomLevel: ReaderConfig.maxZoom,
      enableTextSelection: true,
      interactionMode: PdfInteractionMode.pan,
    );

    // Apply custom FlipWidget (paint-phase only, no layout issues)
    if (_flipHorizontal || _flipVertical) {
      pdfViewer = FlipWidget(
        flipX: _flipHorizontal,
        flipY: _flipVertical,
        child: pdfViewer,
      );
    }

    // Apply dark mode color inversion
    if (_darkModeEnabled) {
      pdfViewer = InvertColors(enabled: true, child: pdfViewer);
    }

    // Wrap with gesture listener
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: pdfViewer,
    );
  }

  Widget _buildTransitionOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pageTransitionAnim,
        builder: (_, __) {
          final p = _pageTransitionAnim.value;
          return switch (_activeTransitionType) {
            PageTransitionType.curl => CustomPaint(
              painter: PageCurlPainter(
                progress: p,
                isForward: _pageTransitionForward,
                color: _bgColor,
              ),
            ),
            PageTransitionType.slide => _buildSlide(p),
            PageTransitionType.fade => Container(
              color: _bgColor.withValues(alpha: 1 - p),
            ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  Widget _buildSlide(double p) {
    final w = MediaQuery.of(context).size.width;
    final offset = _pageTransitionForward ? w * (1 - p) : -w * (1 - p);
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Container(color: _bgColor),
    );
  }

  Widget _buildLoading() => Center(
    child: CircularProgressIndicator(
      color: _settings.theme == 'dark' || _darkModeEnabled
          ? Colors.white
          : null,
    ),
  );

  Widget _buildLoadingOverlay() => Container(
    color: Colors.black54,
    child: Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _downloadProgress == null
                    ? 'Loading...'
                    : '${(_downloadProgress! * 100).toInt()}%',
              ),
              if (_downloadProgress != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(value: _downloadProgress),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _cancelToken?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            'Load Failed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _settings.theme == 'dark' || _darkModeEnabled
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _settings.theme == 'dark' || _darkModeEnabled
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _loadPdfFile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ========== Top Bar ==========

  Widget _buildTopBar() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: FadeTransition(
      opacity: _controlsFadeAnim,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _IconBtn(Icons.search, _showSearchDialog),
                  _IconBtn(Icons.bookmark_add_outlined, _addBookmark),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 22,
                    ),
                    onSelected: (a) {
                      switch (a) {
                        case 'bookmarks':
                          _showBookmarks();
                        case 'goto':
                          _showGoToDialog();
                        case 'outline':
                          _pdfViewerKey.currentState?.openBookmarkView();
                        case 'settings':
                          _toggleSettings();
                        case 'save':
                          _saveOffline();
                        case 'share':
                          _share();
                        case 'resetZoom':
                          _resetZoom();
                        case 'resetFlip':
                          _resetFlip();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'bookmarks',
                        child: Text('Bookmarks'),
                      ),
                      const PopupMenuItem(
                        value: 'goto',
                        child: Text('Go to Page'),
                      ),
                      const PopupMenuItem(
                        value: 'outline',
                        child: Text('Outline'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Settings'),
                      ),
                      const PopupMenuItem(
                        value: 'resetZoom',
                        child: Text('Reset Zoom'),
                      ),
                      if (_flipHorizontal || _flipVertical)
                        const PopupMenuItem(
                          value: 'resetFlip',
                          child: Text('Reset Flip'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'save',
                        child: Text('Save Offline'),
                      ),
                      const PopupMenuItem(value: 'share', child: Text('Share')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // ========== Bottom Bar ==========

  Widget _buildBottomBar() {
    final page = _isScrubbing ? _sliderValue.round() : _currentPage;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _controlsFadeAnim,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black54,
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_totalPages > 1 && _settings.showPageNumber)
                      _buildSlider(page),
                    const SizedBox(height: 4),
                    _buildCompactControls(page),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(int page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$page',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _sliderValue.clamp(1, _totalPages.toDouble()),
                min: 1,
                max: _totalPages > 0 ? _totalPages.toDouble() : 1,
                onChanged: (v) => setState(() {
                  _isScrubbing = true;
                  _sliderValue = v;
                }),
                onChangeEnd: (v) {
                  setState(() => _isScrubbing = false);
                  _jumpToPage(v.round());
                },
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$_totalPages',
              style: TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControls(int page) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const SizedBox(width: 4),
            // Navigation
            _CompactBtn(
              Icons.chevron_left,
              _currentPage > 1 ? _goPrev : null,
              size: 20,
            ),
            if (_settings.showPageNumber)
              _PageChip(page, _totalPages, _showGoToDialog),
            _CompactBtn(
              Icons.chevron_right,
              _currentPage < _totalPages ? _goNext : null,
              size: 20,
            ),
            _Divider(),

            // Zoom controls
            _CompactBtn(
              Icons.remove,
              _zoomLevel > ReaderConfig.minZoom ? _zoomOut : null,
            ),
            _ZoomChip(_zoomLevel, _resetZoom),
            _CompactBtn(
              Icons.add,
              _zoomLevel < ReaderConfig.maxZoom ? _zoomIn : null,
            ),
            _Divider(),

            // Fit Mode Toggle
            _FitModeToggle(fitMode: _fitMode, onToggle: _toggleFitMode),
            _Divider(),

            // Flip Horizontal
            _CompactBtn(
              Icons.flip,
              _toggleFlipHorizontal,
              active: _flipHorizontal,
              tooltip: 'Flip Horizontal',
            ),

            // Flip Vertical
            _CompactBtn(
              Icons.swap_vert,
              _toggleFlipVertical,
              active: _flipVertical,
              tooltip: 'Flip Vertical',
            ),

            // Dark Mode
            _CompactBtn(
              _darkModeEnabled ? Icons.light_mode : Icons.dark_mode,
              _toggleDarkMode,
              active: _darkModeEnabled,
              tooltip: _darkModeEnabled ? 'Light Mode' : 'Dark Mode',
            ),
            _Divider(),

            // Other controls
            _CompactBtn(
              Icons.grid_view,
              _togglePageGrid,
              active: _showPageGrid,
            ),
            _CompactBtn(Icons.tune, _toggleSettings, active: _showSettings),
            _CompactBtn(Icons.bookmark_border, _showBookmarks),
            _CompactBtn(Icons.share_outlined, _share),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ========== Page Grid ==========

  Widget _buildPageGrid() {
    final w = MediaQuery.of(context).size.width;
    final panelW = math.min(200.0, w * 0.5);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {},
        child: SafeArea(
          left: false,
          child: Container(
            width: panelW,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: const Offset(-3, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pages ($_totalPages)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _togglePageGrid,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _totalPages,
                    itemBuilder: (_, i) {
                      final p = i + 1;
                      return _PageThumb(
                        page: p,
                        isCurrent: p == _currentPage,
                        identifier: widget.identifier,
                        manager: _thumbnailManager,
                        localThumbProvider: (widget.identifier == null)
                            ? _getLocalThumb
                            : null,
                        onTap: () {
                          _jumpToPage(p);
                          _togglePageGrid();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== Settings Panel ==========

  Widget _buildSettingsPanel() => GestureDetector(
    onTap: _toggleSettings,
    child: Container(
      color: Colors.black54,
      child: Center(
        child: GestureDetector(
          onTap: () {},
          child: Card(
            margin: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
              child: SettingsPanel(
                settings: _settings,
                onChanged: _updateSettings,
                onClose: _toggleSettings,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ========== Compact UI Components ==========

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, color: Colors.white, size: 22),
    onPressed: onTap,
    padding: const EdgeInsets.all(8),
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

class _CompactBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final String? tooltip;

  const _CompactBtn(
    this.icon,
    this.onTap, {
    this.active = false,
    this.size = 18,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active
            ? Theme.of(context).primaryColor.withValues(alpha: 0.25)
            : Colors.white10,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: size,
              color: onTap == null
                  ? Colors.white24
                  : active
                  ? Theme.of(context).primaryColor
                  : Colors.white,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _FitModeToggle extends StatelessWidget {
  final FitMode fitMode;
  final VoidCallback onToggle;

  const _FitModeToggle({required this.fitMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (fitMode) {
      FitMode.fitWidth => (Icons.width_normal, 'W'),
      FitMode.fitHeight => (Icons.height, 'H'),
      FitMode.custom => (Icons.aspect_ratio, 'C'),
    };

    return Tooltip(
      message: switch (fitMode) {
        FitMode.fitWidth => 'Fit Width (tap for Height)',
        FitMode.fitHeight => 'Fit Height (tap for Width)',
        FitMode.custom => 'Custom Zoom (tap for Width)',
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  final int current, total;
  final VoidCallback onTap;
  const _PageChip(this.current, this.total, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$current/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ZoomChip extends StatelessWidget {
  final double zoom;
  final VoidCallback onTap;
  const _ZoomChip(this.zoom, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Reset Zoom',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${(zoom * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.white24,
  );
}

// ========== Page Thumbnail ==========

class _PageThumb extends StatefulWidget {
  final int page;
  final bool isCurrent;
  final String? identifier;
  final ArchivePageThumbnailManager manager;
  final VoidCallback onTap;
  final Future<RgbaThumb?> Function(int pageNumber)? localThumbProvider;

  const _PageThumb({
    required this.page,
    required this.isCurrent,
    this.identifier,
    required this.manager,
    required this.onTap,
    this.localThumbProvider,
  });
  @override
  State<_PageThumb> createState() => _PageThumbState();
}

class _PageThumbState extends State<_PageThumb> {
  Uint8List? _encodedBytes;
  bool _loading = true;
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _encodedBytes = null;
    });
    _uiImage?.dispose();
    _uiImage = null;

    // 1) Archive thumbnails
    if (widget.identifier != null) {
      final r = await SafeAsync.run(
        () => widget.manager.getPageThumbnail(
          widget.identifier!,
          widget.page - 1,
          scale: 1,
        ),
        operationName: 'Thumb (archive)',
      );

      if (!mounted) return;
      r.when(
        success: (d) => setState(() {
          _encodedBytes = d;
          _loading = false;
        }),
        failure: (_, __) => setState(() => _loading = false),
      );
      return;
    }

    // 2) Local thumbnails via PdfViewerPlatform
    if (widget.localThumbProvider != null) {
      final r = await SafeAsync.run<RgbaThumb?>(
        () => widget.localThumbProvider!(widget.page),
        operationName: 'Thumb (local)',
      );

      if (!mounted) return;

      RgbaThumb? thumb;
      r.when(success: (t) => thumb = t, failure: (_, __) => thumb = null);

      if (thumb == null) {
        setState(() => _loading = false);
        return;
      }

      final imgRes = await SafeAsync.run<ui.Image>(
        () => _rgbaToUiImage(thumb!),
        operationName: 'Thumb decode',
      );

      if (!mounted) return;

      imgRes.when(
        success: (img) => setState(() {
          _uiImage = img;
          _loading = false;
        }),
        failure: (_, __) => setState(() => _loading = false),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(covariant _PageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page ||
        oldWidget.identifier != widget.identifier ||
        oldWidget.localThumbProvider != widget.localThumbProvider) {
      _load();
    }
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    super.dispose();
  }

  Future<ui.Image> _rgbaToUiImage(RgbaThumb t) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      t.pixels,
      t.width,
      t.height,
      ui.PixelFormat.rgba8888,
      (img) => c.complete(img),
    );
    return c.future;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.isCurrent
              ? Theme.of(context).primaryColor
              : Colors.white24,
          width: widget.isCurrent ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              Container(
                color: Colors.grey[900],
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white30,
                    ),
                  ),
                ),
              )
            else if (_uiImage != null)
              RawImage(image: _uiImage!, fit: BoxFit.cover)
            else if (_encodedBytes != null)
              Image.memory(_encodedBytes!, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[850],
                child: Center(
                  child: Icon(
                    Icons.description,
                    color: Colors.white24,
                    size: 20,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  '${widget.page}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: widget.isCurrent
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (widget.isCurrent)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ========== Page Curl Painter ==========

class PageCurlPainter extends CustomPainter {
  final double progress;
  final bool isForward;
  final Color color;
  PageCurlPainter({
    required this.progress,
    required this.isForward,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final curlX = isForward
        ? size.width * (1 - progress * 0.3)
        : size.width * progress * 0.3;

    canvas.drawRect(
      Rect.fromLTWH(
        isForward ? curlX - 20 : 0,
        0,
        isForward ? 20 : curlX + 20,
        size.height,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final path = Path();
    if (isForward) {
      path.moveTo(curlX, 0);
      path.quadraticBezierTo(
        curlX + 35 * progress,
        size.height / 2,
        curlX,
        size.height,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(curlX, 0);
      path.quadraticBezierTo(
        curlX - 35 * progress,
        size.height / 2,
        curlX,
        size.height,
      );
      path.lineTo(0, size.height);
      path.lineTo(0, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(curlX, 0),
      Offset(curlX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * progress)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(PageCurlPainter old) =>
      progress != old.progress || isForward != old.isForward;
}

// ========== AnimatedBuilder ==========

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);
  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ========== Search Dialog ==========

class PdfSearchDialog extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onClear, onNext, onPrev;
  const PdfSearchDialog({
    super.key,
    required this.onSearch,
    required this.onClear,
    required this.onNext,
    required this.onPrev,
  });
  @override
  State<PdfSearchDialog> createState() => _PdfSearchDialogState();
}

class _PdfSearchDialogState extends State<PdfSearchDialog> {
  final _ctrl = TextEditingController();
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onSearch(_ctrl.text.trim());
    setState(() => _searched = true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Search'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter text',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onClear();
                      setState(() => _searched = false);
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _search(),
        ),
        if (_searched)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: widget.onPrev,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: widget.onNext,
                ),
              ],
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          widget.onClear();
          Navigator.pop(context);
        },
        child: const Text('Close'),
      ),
      ElevatedButton(
        onPressed: _ctrl.text.isNotEmpty ? _search : null,
        child: const Text('Search'),
      ),
    ],
  );
}

// ========== Bookmarks Sheet ==========

class BookmarksSheet extends StatefulWidget {
  final List<Bookmark> bookmarks;
  final void Function(Bookmark) onTap;
  final Future<void> Function(Bookmark) onDelete;
  const BookmarksSheet({
    super.key,
    required this.bookmarks,
    required this.onTap,
    required this.onDelete,
  });
  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  late List<Bookmark> _list;
  @override
  void initState() {
    super.initState();
    _list = List.from(widget.bookmarks);
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.55,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.bookmarks, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bookmarks (${_list.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        if (_list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No bookmarks', style: TextStyle(color: Colors.grey)),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final b = _list[i];
                return Dismissible(
                  key: Key(b.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await widget.onDelete(b);
                    setState(() => _list.removeAt(i));
                  },
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          '${b.page}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(
                        b.title ?? 'Page ${b.page}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      dense: true,
                      onTap: () => widget.onTap(b),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

// ========== Settings Panel ==========

class SettingsPanel extends StatelessWidget {
  final ReaderSettings settings;
  final void Function(ReaderSettings) onChanged;
  final VoidCallback onClose;
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.tune, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
          ],
        ),
        const Divider(height: 20),

        const Text(
          'Theme',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _ThemeBtn(
              'Light',
              Colors.white,
              Colors.black,
              settings.theme == 'light',
              () => onChanged(settings.copyWith(theme: 'light')),
            ),
            const SizedBox(width: 8),
            _ThemeBtn(
              'Sepia',
              const Color(0xFFF5E6D3),
              Colors.brown,
              settings.theme == 'sepia',
              () => onChanged(settings.copyWith(theme: 'sepia')),
            ),
            const SizedBox(width: 8),
            _ThemeBtn(
              'Dark',
              Colors.black,
              Colors.white,
              settings.theme == 'dark',
              () => onChanged(settings.copyWith(theme: 'dark')),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text(
          'Transition',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        SegmentedButton<PageTransitionType>(
          segments: const [
            ButtonSegment(
              value: PageTransitionType.curl,
              label: Text('Curl', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: PageTransitionType.slide,
              label: Text('Slide', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: PageTransitionType.fade,
              label: Text('Fade', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: PageTransitionType.none,
              label: Text('None', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {settings.pageTransition},
          onSelectionChanged: (s) =>
              onChanged(settings.copyWith(pageTransition: s.first)),
        ),

        const SizedBox(height: 16),
        const Text(
          'Swipe',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        SegmentedButton<SwipeDirection>(
          segments: const [
            ButtonSegment(
              value: SwipeDirection.horizontal,
              label: Text('H', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: SwipeDirection.vertical,
              label: Text('V', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: SwipeDirection.both,
              label: Text('Both', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {settings.swipeDirection},
          onSelectionChanged: (s) =>
              onChanged(settings.copyWith(swipeDirection: s.first)),
        ),

        const SizedBox(height: 12),
        _Switch(
          'Page Curl',
          settings.enablePageCurl,
          (v) => onChanged(settings.copyWith(enablePageCurl: v)),
        ),
        _Switch(
          'Swipe Navigation',
          settings.enableSwipeNavigation,
          (v) => onChanged(settings.copyWith(enableSwipeNavigation: v)),
        ),
        _Switch(
          'Keep Screen On',
          settings.keepScreenOn,
          (v) => onChanged(settings.copyWith(keepScreenOn: v)),
        ),
        _Switch(
          'Show Page Number',
          settings.showPageNumber,
          (v) => onChanged(settings.copyWith(showPageNumber: v)),
        ),
      ],
    ),
  );
}

class _ThemeBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeBtn(this.label, this.bg, this.fg, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Switch extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _Switch(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(label, style: const TextStyle(fontSize: 13)),
    value: value,
    onChanged: onChanged,
    dense: true,
    contentPadding: EdgeInsets.zero,
  );
}

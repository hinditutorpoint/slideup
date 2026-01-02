import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import '../models/media_file.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../providers/media_provider.dart';
import '../providers/pdf_provider.dart';
import '../widgets/pdf/pdf_thumbnail_panel.dart';
import '../widgets/pdf/pdf_bookmark_widget.dart';
import '../widgets/pdf/pdf_highlights_widget.dart';
import '../widgets/pdf/pdf_extracted_text_widget.dart';
import '../widgets/pdf/pdf_extracted_images_widget.dart';

enum SidePanelType {
  thumbnails,
  bookmarks,
  highlights,
  extractedText,
  extractedImages,
}

class PDFViewerScreen extends ConsumerStatefulWidget {
  final MediaFile mediaFile;
  final List<MediaFile> playlist;
  final int currentIndex;

  const PDFViewerScreen({
    super.key,
    required this.mediaFile,
    required this.playlist,
    required this.currentIndex,
  });

  @override
  ConsumerState<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends ConsumerState<PDFViewerScreen>
    with TickerProviderStateMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();

  late int _currentIndex;
  bool _showControls = true;
  bool _isSearching = false;
  bool _showSidePanel = false;
  SidePanelType _currentPanelType = SidePanelType.thumbnails;

  // Brightness
  bool _autoBrightness = false;
  double _brightness = 0.5;

  // Search
  PdfTextSearchResult? _searchResult;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _sidePanelAnimationController;
  late Animation<double> _sidePanelAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _loadBrightness();
    _initAnimations();
    _initPdfData();

    Future.microtask(() {
      if (mounted) {
        ref.read(mediaProvider.notifier).addToRecent(widget.mediaFile);
      }
    });
  }

  void _initAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
    _controlsAnimationController.forward();

    _sidePanelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidePanelAnimation = CurvedAnimation(
      parent: _sidePanelAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _initPdfData() {
    Future.microtask(() {
      ref
          .read(pdfStateProvider.notifier)
          .loadDocument(
            widget.playlist[_currentIndex].path,
            widget.playlist[_currentIndex].name,
          );
    });
  }

  Future<void> _loadBrightness() async {
    try {
      final brightness = await ScreenBrightness().current;
      if (mounted) {
        setState(() => _brightness = brightness);
      }
    } catch (e) {
      debugPrint('Error loading brightness: $e');
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  void _toggleSidePanel([SidePanelType? type]) {
    setState(() {
      if (type != null && _currentPanelType != type) {
        _currentPanelType = type;
        if (!_showSidePanel) {
          _showSidePanel = true;
          _sidePanelAnimationController.forward();
        }
      } else if (type != null && _currentPanelType == type && _showSidePanel) {
        _showSidePanel = false;
        _sidePanelAnimationController.reverse();
      } else {
        _showSidePanel = !_showSidePanel;
        if (_showSidePanel) {
          if (type != null) _currentPanelType = type;
          _sidePanelAnimationController.forward();
        } else {
          _sidePanelAnimationController.reverse();
        }
      }
    });
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final tapY = details.globalPosition.dy;

    if (tapY < screenHeight / 3) {
      _goToPreviousPage();
    } else if (tapY > screenHeight * 2 / 3) {
      _goToNextPage();
    } else {
      _toggleZoom();
    }
  }

  void _goToNextPage() {
    if (_pdfController.pageNumber < _pdfController.pageCount) {
      _pdfController.nextPage();
      _showPageIndicator();
    }
  }

  void _goToPreviousPage() {
    if (_pdfController.pageNumber > 1) {
      _pdfController.previousPage();
      _showPageIndicator();
    }
  }

  void _toggleZoom() {
    if (_pdfController.zoomLevel > 1.0) {
      _pdfController.zoomLevel = 1.0;
    } else {
      _pdfController.zoomLevel = 2.0;
    }
  }

  void _showPageIndicator() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Page ${_pdfController.pageNumber} of ${_pdfController.pageCount}',
          textAlign: TextAlign.center,
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height / 2,
          left: 100,
          right: 100,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _goToNextDocument() {
    if (_currentIndex < widget.playlist.length - 1) {
      setState(() {
        _currentIndex++;
        _pdfController.jumpToPage(1);
      });
      ref
          .read(pdfStateProvider.notifier)
          .loadDocument(
            widget.playlist[_currentIndex].path,
            widget.playlist[_currentIndex].name,
          );
    }
  }

  void _goToPreviousDocument() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pdfController.jumpToPage(1);
      });
      ref
          .read(pdfStateProvider.notifier)
          .loadDocument(
            widget.playlist[_currentIndex].path,
            widget.playlist[_currentIndex].name,
          );
    }
  }

  void _searchText(String query) {
    if (query.isEmpty) {
      _searchResult?.clear();
      return;
    }

    _searchResult = _pdfController.searchText(query);
    _searchResult?.addListener(() {
      if (_searchResult!.hasResult && mounted) {
        setState(() {});
      }
    });
  }

  void _jumpToPage(int page) {
    _pdfController.jumpToPage(page);
    if (_isSmallScreen && _showSidePanel) {
      _toggleSidePanel();
    }
  }

  bool get _isSmallScreen => MediaQuery.of(context).size.width < 600;

  //bool get _isLandscape =>
  //  MediaQuery.of(context).orientation == Orientation.landscape;

  double get _sidePanelWidth {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return 350;
    if (screenWidth >= 900) return 300;
    if (screenWidth >= 600) return 280;
    return screenWidth * 0.85;
  }

  void _adjustBrightness(double value) async {
    setState(() {
      _brightness = value;
      _autoBrightness = false;
    });
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (e) {
      debugPrint('Error setting brightness: $e');
    }
  }

  void _toggleAutoBrightness() async {
    setState(() => _autoBrightness = !_autoBrightness);
    if (_autoBrightness) {
      try {
        await ScreenBrightness().resetApplicationScreenBrightness();
      } catch (e) {
        debugPrint('Error resetting brightness: $e');
      }
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _searchController.dispose();
    _controlsAnimationController.dispose();
    _sidePanelAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = widget.playlist[_currentIndex];
    final pdfState = ref.watch(pdfStateProvider);

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Row(
        children: [
          // Side Panel
          AnimatedBuilder(
            animation: _sidePanelAnimation,
            builder: (context, child) {
              final width = _sidePanelWidth * _sidePanelAnimation.value;
              if (width == 0) return const SizedBox.shrink();

              return SizedBox(
                width: width,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: _sidePanelWidth,
                    child: _buildSidePanel(),
                  ),
                ),
              );
            },
          ),

          // Main PDF Viewer
          Expanded(
            child: GestureDetector(
              onTap: _toggleControls,
              onDoubleTapDown: _handleDoubleTap,
              onDoubleTap: () {},
              child: Stack(
                children: [
                  SfPdfViewer.file(
                    File(currentFile.path),
                    key: _pdfViewerKey,
                    controller: _pdfController,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    enableDoubleTapZooming: false,
                    enableTextSelection: true,
                    pageSpacing: 4,
                    scrollDirection: PdfScrollDirection.vertical,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    onDocumentLoaded: (details) {
                      ref
                          .read(pdfStateProvider.notifier)
                          .setPageCount(details.document.pages.count);
                      if (mounted) setState(() {});
                    },
                    onPageChanged: (details) {
                      ref
                          .read(pdfStateProvider.notifier)
                          .setCurrentPage(details.newPageNumber);
                      if (mounted) setState(() {});
                    },
                  ),

                  // Bottom controls
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: FadeTransition(
                        opacity: _controlsAnimation,
                        child: _buildBottomControls(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(pdfState),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildPanelTabs(),
          Expanded(child: _buildPanelContent()),
        ],
      ),
    );
  }

  Widget _buildPanelTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPanelTab(SidePanelType.thumbnails, Icons.grid_view, 'Pages'),
            _buildPanelTab(
              SidePanelType.bookmarks,
              Icons.bookmark,
              'Bookmarks',
            ),
            _buildPanelTab(
              SidePanelType.highlights,
              Icons.highlight,
              'Highlights',
            ),
            _buildPanelTab(
              SidePanelType.extractedText,
              Icons.text_snippet,
              'Text',
            ),
            _buildPanelTab(
              SidePanelType.extractedImages,
              Icons.image,
              'Images',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelTab(SidePanelType type, IconData icon, String label) {
    final isSelected = _currentPanelType == type;
    final isCompact = _sidePanelWidth < 300;

    return InkWell(
      onTap: () => setState(() => _currentPanelType = type),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isCompact ? 16 : 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).iconTheme.color,
            ),
            if (!isCompact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    final currentFile = widget.playlist[_currentIndex];

    switch (_currentPanelType) {
      case SidePanelType.thumbnails:
        return PdfThumbnailPanel(
          filePath: currentFile.path,
          currentPage: _pdfController.pageNumber,
          onPageSelected: _jumpToPage,
          pdfController: _pdfController,
        );
      case SidePanelType.bookmarks:
        return PdfBookmarkWidget(
          onPageSelected: _jumpToPage,
          currentPage: _pdfController.pageNumber,
        );
      case SidePanelType.highlights:
        return PdfHighlightsWidget(
          onPageSelected: _jumpToPage,
          currentPage: _pdfController.pageNumber,
        );
      case SidePanelType.extractedText:
        return PdfExtractedTextWidget(
          filePath: currentFile.path,
          fileName: currentFile.name,
          onPageSelected: _jumpToPage,
        );
      case SidePanelType.extractedImages:
        return PdfExtractedImagesWidget(
          filePath: currentFile.path,
          fileName: currentFile.name,
          onPageSelected: _jumpToPage,
        );
    }
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => _toggleSidePanel(SidePanelType.thumbnails),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.playlist[_currentIndex].name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Page ${_pdfController.pageNumber} of ${_pdfController.pageCount}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showSidePanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
          ),
          tooltip: 'Toggle Panel',
          onPressed: () => _toggleSidePanel(),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => setState(() => _isSearching = true),
        ),
        _buildMoreMenu(),
      ],
    );
  }

  Widget _buildMoreMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        _buildMenuItem('pages', Icons.grid_view, 'View All Pages'),
        _buildMenuItem('bookmarks', Icons.bookmark, 'Bookmarks'),
        _buildMenuItem('highlights', Icons.highlight, 'Highlights'),
        const PopupMenuDivider(),
        _buildMenuItem('extract_text', Icons.text_snippet, 'Extract Text'),
        _buildMenuItem('extract_images', Icons.image, 'Extract Images'),
        const PopupMenuDivider(),
        _buildMenuItem('brightness', Icons.brightness_6, 'Brightness'),
        _buildMenuItem('goto', Icons.pin_drop, 'Go to Page'),
        _buildMenuItem('info', Icons.info_outline, 'Document Info'),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String text,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text)],
      ),
    );
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'pages':
        _toggleSidePanel(SidePanelType.thumbnails);
        break;
      case 'bookmarks':
        _toggleSidePanel(SidePanelType.bookmarks);
        break;
      case 'highlights':
        _toggleSidePanel(SidePanelType.highlights);
        break;
      case 'extract_text':
        _toggleSidePanel(SidePanelType.extractedText);
        break;
      case 'extract_images':
        _toggleSidePanel(SidePanelType.extractedImages);
        break;
      case 'brightness':
        _showBrightnessDialog();
        break;
      case 'goto':
        _showGoToPageDialog();
        break;
      case 'info':
        _showDocumentInfo();
        break;
    }
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchResult?.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search in document...',
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchResult?.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: _searchText,
      ),
      actions: [
        if (_searchResult != null && _searchResult!.hasResult)
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_searchResult!.currentInstanceIndex}/${_searchResult!.totalInstanceCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: () {
                  _searchResult!.previousInstance();
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () {
                  _searchResult!.nextInstance();
                  setState(() {});
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page slider
            Row(
              children: [
                Text(
                  '${_pdfController.pageNumber}',
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: _pdfController.pageCount > 0
                        ? _pdfController.pageNumber.toDouble()
                        : 1,
                    min: 1,
                    max: _pdfController.pageCount > 0
                        ? _pdfController.pageCount.toDouble()
                        : 1,
                    divisions: _pdfController.pageCount > 1
                        ? _pdfController.pageCount - 1
                        : 1,
                    onChanged: (value) {
                      _pdfController.jumpToPage(value.toInt());
                    },
                  ),
                ),
                Text(
                  '${_pdfController.pageCount}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.skip_previous,
                  label: 'Prev Doc',
                  onPressed: _currentIndex > 0 ? _goToPreviousDocument : null,
                ),
                _buildControlButton(
                  icon: Icons.navigate_before,
                  label: 'Prev',
                  onPressed: _pdfController.pageNumber > 1
                      ? _goToPreviousPage
                      : null,
                ),
                _buildControlButton(
                  icon: Icons.zoom_out,
                  label: 'Zoom -',
                  onPressed: _pdfController.zoomLevel > 1
                      ? () => _pdfController.zoomLevel -= 0.25
                      : null,
                ),
                _buildControlButton(
                  icon: Icons.zoom_in,
                  label: 'Zoom +',
                  onPressed: () => _pdfController.zoomLevel += 0.25,
                ),
                _buildControlButton(
                  icon: Icons.navigate_next,
                  label: 'Next',
                  onPressed:
                      _pdfController.pageNumber < _pdfController.pageCount
                      ? _goToNextPage
                      : null,
                ),
                _buildControlButton(
                  icon: Icons.skip_next,
                  label: 'Next Doc',
                  onPressed: _currentIndex < widget.playlist.length - 1
                      ? _goToNextDocument
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          color: onPressed != null ? Colors.white : Colors.grey,
          onPressed: onPressed,
          iconSize: _isSmallScreen ? 20 : 24,
        ),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white70 : Colors.grey,
            fontSize: _isSmallScreen ? 9 : 10,
          ),
        ),
      ],
    );
  }

  Widget? _buildFloatingActions(PdfState pdfState) {
    if (!_showControls) return null;

    return FadeTransition(
      opacity: _controlsAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'bookmark',
            mini: true,
            backgroundColor:
                pdfState.bookmarks.contains(_pdfController.pageNumber)
                ? Theme.of(context).primaryColor
                : null,
            onPressed: () {
              ref
                  .read(pdfStateProvider.notifier)
                  .toggleBookmark(_pdfController.pageNumber);
            },
            child: Icon(
              pdfState.bookmarks.contains(_pdfController.pageNumber)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'highlight',
            mini: true,
            onPressed: _showHighlightDialog,
            child: const Icon(Icons.highlight),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'panel',
            mini: true,
            onPressed: () => _toggleSidePanel(),
            child: Icon(_showSidePanel ? Icons.close : Icons.menu),
          ),
        ],
      ),
    );
  }

  void _showHighlightDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor = ref.read(pdfStateProvider).currentHighlightColor;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Highlight'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select color:'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children:
                      [
                        Colors.yellow,
                        Colors.green.shade300,
                        Colors.blue.shade300,
                        Colors.pink.shade300,
                        Colors.orange.shade300,
                      ].map((color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedColor = color);
                            ref
                                .read(pdfStateProvider.notifier)
                                .setHighlightColor(color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: selectedColor == color
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black54,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(pdfStateProvider.notifier)
                      .addHighlight(
                        pageNumber: _pdfController.pageNumber,
                        text: 'Highlight on page ${_pdfController.pageNumber}',
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Highlight added')),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBrightnessDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Brightness'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.brightness_low),
                  Expanded(
                    child: Slider(
                      value: _brightness,
                      onChanged: (value) {
                        setDialogState(() => _brightness = value);
                        _adjustBrightness(value);
                      },
                    ),
                  ),
                  const Icon(Icons.brightness_high),
                ],
              ),
              Text('${(_brightness * 100).toInt()}%'),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto Brightness'),
                value: _autoBrightness,
                onChanged: (value) {
                  setDialogState(() {});
                  _toggleAutoBrightness();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoToPageDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 - ${_pdfController.pageCount}',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page > 0 && page <= _pdfController.pageCount) {
              _pdfController.jumpToPage(page);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null &&
                  page > 0 &&
                  page <= _pdfController.pageCount) {
                _pdfController.jumpToPage(page);
                Navigator.pop(context);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showDocumentInfo() {
    final currentFile = widget.playlist[_currentIndex];
    final file = File(currentFile.path);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', currentFile.name),
            _buildInfoRow('Pages', '${_pdfController.pageCount}'),
            _buildInfoRow('Size', _formatFileSize(file.lengthSync())),
            _buildInfoRow('Path', currentFile.path),
            _buildInfoRow('Modified', _formatDateTime(file.lastModifiedSync())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

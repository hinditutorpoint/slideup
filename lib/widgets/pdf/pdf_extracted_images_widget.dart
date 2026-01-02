import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'dart:io';
import '../../providers/pdf_provider.dart';
import 'dart:typed_data';

class PdfExtractedImagesWidget extends ConsumerStatefulWidget {
  final String? filePath;
  final String? fileName;
  final Function(int)? onPageSelected;

  const PdfExtractedImagesWidget({
    super.key,
    this.filePath,
    this.fileName,
    this.onPageSelected,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  @override
  ConsumerState<PdfExtractedImagesWidget> createState() =>
      _PdfExtractedImagesWidgetState();
}

class _PdfExtractedImagesWidgetState
    extends ConsumerState<PdfExtractedImagesWidget> {
  bool _isLoading = false;
  String? _error;
  List<ExtractedImageInfo> _images = [];
  List<ExtractedFolder> _folders = [];
  String? _currentFolderPath;
  bool _showingFolders = true;
  bool _isGridView = true;
  Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(PdfExtractedImagesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (widget.hasFile) {
      _showingFolders = false;
      await _loadCurrentFileImages();
    } else {
      _showingFolders = true;
      await _loadFolders();
    }
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final folders = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedFolders(ExtractedType.images);
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentFileImages() async {
    if (!widget.hasFile) return;

    setState(() => _isLoading = true);

    try {
      final extractDir = await ref
          .read(pdfStateProvider.notifier)
          .getExtractionDirectory(ExtractedType.images);

      final images = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedImagesFromFolder(extractDir);

      setState(() {
        _images = images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFolderImages(String folderPath) async {
    setState(() => _isLoading = true);

    try {
      final images = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedImagesFromFolder(folderPath);

      setState(() {
        _images = images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _extractAllImages() async {
    try {
      setState(() => _isLoading = true);
      // Use extractAllPages to extract pages as images since there's no dedicated image extraction method
      final pages = await ref.read(pdfStateProvider.notifier).extractAllPages();

      // Convert pages to images format for this widget
      final images = pages
          .map(
            (page) => ExtractedImageInfo(
              pageNumber: page.pageNumber,
              imageIndex: page.pageNumber, // Use page number as image index
              filePath: page.filePath,
              extractedAt: page.extractedAt,
              width: 612, // Default PDF page width
              height: 792, // Default PDF page height
              fileSize: page.fileSize,
            ),
          )
          .toList();

      setState(() {
        _images = images;
        _isLoading = false;
      });

      if (images.isEmpty) {
        _showInfo('No images found in this PDF');
      } else {
        _showSuccess('Extracted ${images.length} images');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to extract images: $e');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }

      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices = Set.from(List.generate(_images.length, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final canExtract = widget.hasFile && !_isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        if (_isSelectionMode)
          _buildSelectionHeader(isCompact)
        else
          _buildHeader(pdfState, canExtract, isCompact),
        if (_isLoading) _buildLoadingIndicator(pdfState),
        if (_error != null) _buildErrorWidget(),
        Expanded(
          child: _showingFolders && !widget.hasFile
              ? _buildFoldersList(isCompact)
              : _buildImagesList(isCompact),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearSelection,
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedIndices.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
          const Spacer(),
          TextButton(onPressed: _selectAll, child: const Text('Select All')),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleSelectionAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 12),
                    Text('Save Selected'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 12),
                    Text('Share Selected'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Delete Selected',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PdfState pdfState, bool canExtract, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showingFolders && !widget.hasFile
                      ? 'Extracted Image Folders'
                      : '${_images.length} Image${_images.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? 14 : 16,
                  ),
                ),
                if (_currentFolderPath != null && !widget.hasFile)
                  GestureDetector(
                    onTap: _navigateBack,
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Back to folders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!_showingFolders || widget.hasFile) ...[
            _buildViewModeToggle(isCompact),
            const SizedBox(width: 8),
          ],
          if (canExtract)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _extractAllImages,
              icon: Icon(Icons.image, size: isCompact ? 16 : 18),
              label: Text(
                'Extract',
                style: TextStyle(fontSize: isCompact ? 12 : 14),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isCompact ? 8 : 10,
                ),
              ),
            ),
          if (_images.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
              onSelected: _handleBulkAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outlined, size: 18),
                      SizedBox(width: 12),
                      Text('Select'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'save_all',
                  child: Row(
                    children: [
                      Icon(Icons.save, size: 18),
                      SizedBox(width: 12),
                      Text('Save All to Gallery'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share_all',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 18),
                      SizedBox(width: 12),
                      Text('Share All'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete All', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _navigateBack() {
    setState(() {
      _currentFolderPath = null;
      _showingFolders = true;
      _images.clear();
    });
    _loadFolders();
  }

  Widget _buildViewModeToggle(bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton(true, Icons.grid_view, isCompact),
          _buildViewModeButton(false, Icons.list, isCompact),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(bool isGrid, IconData icon, bool isCompact) {
    final isSelected = _isGridView == isGrid;
    return InkWell(
      onTap: () => setState(() => _isGridView = isGrid),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: isCompact ? 18 : 20,
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(PdfState pdfState) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (pdfState.loadingProgress > 0)
            LinearProgressIndicator(value: pdfState.loadingProgress)
          else
            const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            pdfState.loadingMessage ?? 'Loading...',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersList(bool isCompact) {
    if (_folders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open,
        title: 'No Extracted Images',
        subtitle: 'Open a PDF to extract images',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return _buildFolderCard(folder, isCompact);
      },
    );
  }

  Widget _buildFolderCard(ExtractedFolder folder, bool isCompact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: isCompact ? 44 : 48,
          height: isCompact ? 44 : 48,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.photo_library,
            color: Theme.of(context).primaryColor,
            size: isCompact ? 22 : 24,
          ),
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: isCompact ? 14 : 16),
        ),
        subtitle: Text(
          '${folder.itemCount} image${folder.itemCount != 1 ? 's' : ''} • ${_formatDate(folder.createdAt)}',
          style: TextStyle(fontSize: isCompact ? 11 : 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
          onSelected: (value) => _handleFolderMenuAction(value, folder),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 18),
                  SizedBox(width: 12),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'save_all',
              child: Row(
                children: [
                  Icon(Icons.save, size: 18),
                  SizedBox(width: 12),
                  Text('Save All to Gallery'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 18),
                  SizedBox(width: 12),
                  Text('Share All'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openFolder(folder),
      ),
    );
  }

  void _handleFolderMenuAction(String action, ExtractedFolder folder) async {
    switch (action) {
      case 'open':
        await _openFolder(folder);
        break;
      case 'save_all':
        await _saveAllImagesToGallery(folder.path);
        break;
      case 'share':
        await _shareFolder(folder);
        break;
      case 'delete':
        await _confirmDeleteFolder(folder);
        break;
    }
  }

  Future<void> _openFolder(ExtractedFolder folder) async {
    setState(() {
      _currentFolderPath = folder.path;
      _showingFolders = false;
    });
    await _loadFolderImages(folder.path);
  }

  Future<void> _saveAllImagesToGallery(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      int savedCount = 0;

      await for (final entity in dir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.png') || entity.path.endsWith('.jpg'))) {
          final bytes = await entity.readAsBytes();
          final result = await SaverGallery.saveImage(
            bytes,
            quality: 100,
            fileName:
                'img_${DateTime.now().millisecondsSinceEpoch}_$savedCount',
            androidRelativePath: 'Pictures/SlideUp_Extracted',
            skipIfExists: false,
          );
          if (result.isSuccess) savedCount++;
        }
      }

      _showSuccess('Saved $savedCount images to gallery');
    } catch (e) {
      _showError('Failed to save images: $e');
    }
  }

  Future<void> _shareFolder(ExtractedFolder folder) async {
    try {
      final dir = Directory(folder.path);
      final files = <XFile>[];

      await for (final entity in dir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.png') || entity.path.endsWith('.jpg'))) {
          files.add(XFile(entity.path));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Images from ${folder.name}',
            files: files,
            subject: 'Images from ${folder.name}',
          ),
        );
      }
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  Future<void> _confirmDeleteFolder(ExtractedFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'This will delete "${folder.name}" and all ${folder.itemCount} images. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(pdfStateProvider.notifier)
          .deleteExtractedFolder(folder.path);
      await _loadFolders();
      _showSuccess('Folder deleted');
    }
  }

  Widget _buildImagesList(bool isCompact) {
    if (_images.isEmpty && !_isLoading) {
      return _buildEmptyState(
        icon: Icons.image_not_supported,
        title: widget.hasFile ? 'No Images Extracted' : 'No Images',
        subtitle: widget.hasFile
            ? 'Tap "Extract" to find images in this PDF'
            : 'Select a folder to view images',
      );
    }

    if (_isGridView) {
      return _buildGridView(isCompact);
    } else {
      return _buildListView(isCompact);
    }
  }

  Widget _buildGridView(bool isCompact) {
    final crossAxisCount = isCompact ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(index);
            } else {
              _showImagePreview(image, index);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() => _isSelectionMode = true);
            }
            _toggleSelection(index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade700,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildImageWidget(image),
                ),
                // Page number overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(7),
                      ),
                    ),
                    child: Text(
                      'P${image.pageNumber} #${image.imageIndex}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Selection checkbox
                if (_isSelectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                // Menu button
                if (!_isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(16),
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (value) =>
                            _handleImageMenuAction(value, image, index),
                        itemBuilder: (context) => _buildImageMenuItems(image),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(bool isCompact) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        final isSelected = _selectedIndices.contains(index);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : null,
          child: ListTile(
            leading: GestureDetector(
              onTap: () => _showImagePreview(image, index),
              child: Container(
                width: isCompact ? 50 : 60,
                height: isCompact ? 50 : 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _buildImageWidget(image),
                ),
              ),
            ),
            title: Text(
              'Page ${image.pageNumber} - Image ${image.imageIndex}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            subtitle: Text(
              '${image.width}x${image.height} • ${_formatFileSize(image.fileSize)}',
              style: TextStyle(fontSize: isCompact ? 11 : 12),
            ),
            trailing: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(index),
                  )
                : PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
                    onSelected: (value) =>
                        _handleImageMenuAction(value, image, index),
                    itemBuilder: (context) => _buildImageMenuItems(image),
                  ),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(index);
              } else {
                _showImagePreview(image, index);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() => _isSelectionMode = true);
              }
              _toggleSelection(index);
            },
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(ExtractedImageInfo image) {
    if (image.filePath != null && File(image.filePath!).existsSync()) {
      return Image.file(
        File(image.filePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    } else if (image.imageData != null) {
      return Image.memory(
        image.imageData!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    } else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade800,
      child: Icon(Icons.broken_image, color: Colors.grey.shade600, size: 32),
    );
  }

  List<PopupMenuEntry<String>> _buildImageMenuItems(ExtractedImageInfo image) {
    return [
      const PopupMenuItem(
        value: 'view',
        child: Row(
          children: [
            Icon(Icons.fullscreen, size: 18),
            SizedBox(width: 12),
            Text('View'),
          ],
        ),
      ),
      if (widget.onPageSelected != null)
        const PopupMenuItem(
          value: 'goto',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18),
              SizedBox(width: 12),
              Text('Go to Page'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'save',
        child: Row(
          children: [
            Icon(Icons.save, size: 18),
            SizedBox(width: 12),
            Text('Save to Gallery'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'share',
        child: Row(
          children: [
            Icon(Icons.share, size: 18),
            SizedBox(width: 12),
            Text('Share'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'properties',
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 12),
            Text('Properties'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _handleImageMenuAction(
    String action,
    ExtractedImageInfo image,
    int index,
  ) {
    switch (action) {
      case 'view':
        _showImagePreview(image, index);
        break;
      case 'goto':
        widget.onPageSelected?.call(image.pageNumber);
        break;
      case 'save':
        _saveImageToGallery(image);
        break;
      case 'share':
        _shareImage(image);
        break;
      case 'properties':
        _showImageProperties(image);
        break;
      case 'delete':
        _confirmDeleteImage(image, index);
        break;
    }
  }

  void _handleBulkAction(String action) {
    switch (action) {
      case 'select':
        _toggleSelectionMode();
        break;
      case 'save_all':
        _saveAllImages();
        break;
      case 'share_all':
        _shareAllImages();
        break;
      case 'delete_all':
        _confirmDeleteAllImages();
        break;
    }
  }

  void _handleSelectionAction(String action) async {
    if (_selectedIndices.isEmpty) return;

    final selectedImages = _selectedIndices.map((i) => _images[i]).toList();

    switch (action) {
      case 'save':
        await _saveSelectedImages(selectedImages);
        break;
      case 'share':
        await _shareSelectedImages(selectedImages);
        break;
      case 'delete':
        await _confirmDeleteSelectedImages(selectedImages);
        break;
    }
  }

  void _showImagePreview(ExtractedImageInfo image, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImagePreviewScreen(
          images: _images,
          initialIndex: index,
          onSave: _saveImageToGallery,
          onShare: _shareImage,
          onDelete: (img) {
            final idx = _images.indexOf(img);
            if (idx != -1) {
              _confirmDeleteImage(img, idx);
            }
          },
          onGoToPage: widget.onPageSelected,
        ),
      ),
    );
  }

  Future<void> _saveImageToGallery(ExtractedImageInfo image) async {
    try {
      Uint8List bytes;
      if (image.filePath != null && File(image.filePath!).existsSync()) {
        bytes = await File(image.filePath!).readAsBytes();
      } else if (image.imageData != null) {
        bytes = image.imageData!;
      } else {
        throw Exception('No image data available');
      }

      final result = await SaverGallery.saveImage(
        bytes,
        quality: 100,
        fileName:
            'pdf_p${image.pageNumber}_img${image.imageIndex}_${DateTime.now().millisecondsSinceEpoch}',
        androidRelativePath: 'Pictures/SlideUp_Extracted',
        skipIfExists: false,
      );

      if (result.isSuccess) {
        _showSuccess('Image saved to gallery');
      } else {
        throw Exception('Failed to save');
      }
    } catch (e) {
      _showError('Failed to save image: $e');
    }
  }

  Future<void> _shareImage(ExtractedImageInfo image) async {
    try {
      if (image.filePath != null && File(image.filePath!).existsSync()) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Image from Page ${image.pageNumber}',
            files: [XFile(image.filePath!)],
            subject: 'Image from Page ${image.pageNumber}',
          ),
        );
      } else {
        _showError('Image file not found');
      }
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  void _showImageProperties(ExtractedImageInfo image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page', '${image.pageNumber}'),
            _buildPropertyRow('Image #', '${image.imageIndex}'),
            _buildPropertyRow('Dimensions', '${image.width} x ${image.height}'),
            _buildPropertyRow('Size', _formatFileSize(image.fileSize)),
            _buildPropertyRow('Extracted', _formatDate(image.extractedAt)),
            if (image.filePath != null)
              _buildPropertyRow('Path', image.filePath!),
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

  Future<void> _confirmDeleteImage(ExtractedImageInfo image, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && image.filePath != null) {
      await ref
          .read(pdfStateProvider.notifier)
          .deleteExtractedItem(image.filePath!);
      setState(() {
        _images.removeAt(index);
        _selectedIndices.remove(index);
        // Update indices
        _selectedIndices = _selectedIndices
            .map((i) => i > index ? i - 1 : i)
            .toSet();
      });
      _showSuccess('Image deleted');
    }
  }

  Future<void> _saveAllImages() async {
    try {
      int savedCount = 0;
      for (final image in _images) {
        Uint8List bytes;
        if (image.filePath != null && File(image.filePath!).existsSync()) {
          bytes = await File(image.filePath!).readAsBytes();
        } else if (image.imageData != null) {
          bytes = image.imageData!;
        } else {
          continue;
        }

        final result = await SaverGallery.saveImage(
          bytes,
          quality: 100,
          fileName:
              'pdf_p${image.pageNumber}_img${image.imageIndex}_${DateTime.now().millisecondsSinceEpoch}',
          androidRelativePath: 'Pictures/SlideUp_Extracted',
          skipIfExists: false,
        );
        if (result.isSuccess) savedCount++;
      }
      _showSuccess('Saved $savedCount images to gallery');
    } catch (e) {
      _showError('Failed to save images: $e');
    }
  }

  Future<void> _shareAllImages() async {
    try {
      final files = <XFile>[];
      for (final image in _images) {
        if (image.filePath != null && File(image.filePath!).existsSync()) {
          files.add(XFile(image.filePath!));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Extracted Images',
            subject: 'Extracted Images',
            files: files,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  Future<void> _confirmDeleteAllImages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Images?'),
        content: Text(
          'This will delete all ${_images.length} images. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final image in _images) {
        if (image.filePath != null) {
          await ref
              .read(pdfStateProvider.notifier)
              .deleteExtractedItem(image.filePath!);
        }
      }
      setState(() {
        _images.clear();
        _selectedIndices.clear();
        _isSelectionMode = false;
      });
      _showSuccess('All images deleted');
    }
  }

  Future<void> _saveSelectedImages(List<ExtractedImageInfo> images) async {
    try {
      int savedCount = 0;
      for (final image in images) {
        Uint8List bytes;
        if (image.filePath != null && File(image.filePath!).existsSync()) {
          bytes = await File(image.filePath!).readAsBytes();
        } else if (image.imageData != null) {
          bytes = image.imageData!;
        } else {
          continue;
        }

        final result = await SaverGallery.saveImage(
          bytes,
          quality: 100,
          fileName:
              'pdf_p${image.pageNumber}_img${image.imageIndex}_${DateTime.now().millisecondsSinceEpoch}',
          androidRelativePath: 'Pictures/SlideUp_Extracted',
          skipIfExists: false,
        );
        if (result.isSuccess) savedCount++;
      }
      _clearSelection();
      _showSuccess('Saved $savedCount images');
    } catch (e) {
      _showError('Failed to save: $e');
    }
  }

  Future<void> _shareSelectedImages(List<ExtractedImageInfo> images) async {
    try {
      final files = <XFile>[];
      for (final image in images) {
        if (image.filePath != null && File(image.filePath!).existsSync()) {
          files.add(XFile(image.filePath!));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Selected Extracted Images',
            subject: 'Selected Extracted Images',
            files: files,
          ),
        );
      }
      _clearSelection();
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  Future<void> _confirmDeleteSelectedImages(
    List<ExtractedImageInfo> images,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Images?'),
        content: Text(
          'This will delete ${images.length} selected images. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final image in images) {
        if (image.filePath != null) {
          await ref
              .read(pdfStateProvider.notifier)
              .deleteExtractedItem(image.filePath!);
        }
      }
      setState(() {
        _images.removeWhere((img) => images.contains(img));
        _selectedIndices.clear();
        _isSelectionMode = false;
      });
      _showSuccess('${images.length} images deleted');
    }
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ==================== IMAGE PREVIEW SCREEN ====================

class _ImagePreviewScreen extends StatefulWidget {
  final List<ExtractedImageInfo> images;
  final int initialIndex;
  final Function(ExtractedImageInfo) onSave;
  final Function(ExtractedImageInfo) onShare;
  final Function(ExtractedImageInfo) onDelete;
  final Function(int)? onGoToPage;

  const _ImagePreviewScreen({
    required this.images,
    required this.initialIndex,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
    this.onGoToPage,
  });

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ExtractedImageInfo get _currentImage => widget.images[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Page ${_currentImage.pageNumber} - Image ${_currentImage.imageIndex}',
        ),
        actions: [
          if (widget.onGoToPage != null)
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Go to Page',
              onPressed: () {
                Navigator.pop(context);
                widget.onGoToPage!(_currentImage.pageNumber);
              },
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save to Gallery',
            onPressed: () => widget.onSave(_currentImage),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => widget.onShare(_currentImage),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(_currentImage);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final image = widget.images[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(child: _buildImageWidget(image)),
              );
            },
          ),
          // Page indicator
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(ExtractedImageInfo image) {
    if (image.filePath != null && File(image.filePath!).existsSync()) {
      return Image.file(
        File(image.filePath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (image.imageData != null) {
      return Image.memory(
        image.imageData!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, size: 64, color: Colors.grey.shade600),
        const SizedBox(height: 16),
        Text(
          'Image not available',
          style: TextStyle(color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../providers/pdf_provider.dart';

class PdfExtractedTextWidget extends ConsumerStatefulWidget {
  final String? filePath;
  final String? fileName;
  final Function(int)? onPageSelected;

  const PdfExtractedTextWidget({
    super.key,
    this.filePath,
    this.fileName,
    this.onPageSelected,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  @override
  ConsumerState<PdfExtractedTextWidget> createState() =>
      _PdfExtractedTextWidgetState();
}

class _PdfExtractedTextWidgetState
    extends ConsumerState<PdfExtractedTextWidget> {
  bool _isLoading = false;
  String? _error;
  List<ExtractedTextInfo> _texts = [];
  List<ExtractedFolder> _folders = [];
  String? _currentFolderPath;
  bool _showingFolders = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(PdfExtractedTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (widget.hasFile) {
      _showingFolders = false;
      await _loadCurrentFileTexts();
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
          .getExtractedFolders(ExtractedType.text);
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

  Future<void> _loadCurrentFileTexts() async {
    if (!widget.hasFile) return;

    setState(() => _isLoading = true);

    try {
      final pdfState = ref.read(pdfStateProvider);
      final extractDir = await ref
          .read(pdfStateProvider.notifier)
          .getExtractionDirectory(ExtractedType.text);

      final texts = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedTextsFromFolder(extractDir);

      // Create placeholder items for pages without extracted text
      List<ExtractedTextInfo> allTexts = [];
      for (int i = 1; i <= pdfState.pageCount; i++) {
        final existingText = texts.firstWhere(
          (t) => t.pageNumber == i,
          orElse: () => ExtractedTextInfo(
            pageNumber: i,
            text: '',
            filePath: null,
            extractedAt: DateTime.now(),
          ),
        );
        allTexts.add(existingText);
      }

      setState(() {
        _texts = allTexts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFolderTexts(String folderPath) async {
    setState(() => _isLoading = true);

    try {
      final texts = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedTextsFromFolder(folderPath);

      setState(() {
        _texts = texts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _extractAllText() async {
    try {
      setState(() => _isLoading = true);
      final texts = await ref.read(pdfStateProvider.notifier).extractAllText();
      setState(() {
        _texts = texts;
        _isLoading = false;
      });
      _showSuccess('Extracted text from ${texts.length} pages');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to extract text: $e');
    }
  }

  Future<void> _extractSinglePageText(int pageNumber) async {
    try {
      final text = await ref
          .read(pdfStateProvider.notifier)
          .extractSinglePageText(pageNumber);

      final index = _texts.indexWhere((t) => t.pageNumber == pageNumber);
      if (index != -1) {
        setState(() {
          _texts[index] = text;
        });
      }

      _showSuccess('Text extracted from page $pageNumber');
    } catch (e) {
      _showError('Failed to extract text: $e');
    }
  }

  List<ExtractedTextInfo> get _filteredTexts {
    if (_searchQuery.isEmpty) return _texts;
    return _texts
        .where((t) => t.text.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final canExtract = widget.hasFile && !_isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(pdfState, canExtract, isCompact),
        if (_texts.isNotEmpty || _searchQuery.isNotEmpty)
          _buildSearchBar(isCompact),
        if (_isLoading) _buildLoadingIndicator(pdfState),
        if (_error != null) _buildErrorWidget(),
        Expanded(
          child: _showingFolders && !widget.hasFile
              ? _buildFoldersList(isCompact)
              : _buildTextList(isCompact),
        ),
      ],
    );
  }

  Widget _buildHeader(PdfState pdfState, bool canExtract, bool isCompact) {
    final extractedCount = _texts.where((t) => t.text.isNotEmpty).length;

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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showingFolders && !widget.hasFile
                          ? 'Extracted Text Files'
                          : widget.hasFile
                          ? '$extractedCount/${pdfState.pageCount} Pages'
                          : '${_texts.length} Text${_texts.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 14 : 16,
                      ),
                    ),
                    if (_currentFolderPath != null && !widget.hasFile)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentFolderPath = null;
                            _showingFolders = true;
                            _texts.clear();
                          });
                          _loadFolders();
                        },
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
              if (canExtract)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _extractAllText,
                  icon: Icon(Icons.text_snippet, size: isCompact ? 16 : 18),
                  label: Text(
                    'Extract All',
                    style: TextStyle(fontSize: isCompact ? 12 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: isCompact ? 8 : 10,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.hasFile && pdfState.pageCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildProgressIndicator(
                extractedCount,
                pdfState.pageCount,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int extractedCount, int totalPages) {
    final progress = totalPages > 0 ? extractedCount / totalPages : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$extractedCount of $totalPages extracted',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: 8,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search in extracted text...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isCompact ? 8 : 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
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
        title: 'No Extracted Text',
        subtitle: 'Open a PDF to extract text',
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
            Icons.folder,
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
          '${folder.itemCount} page${folder.itemCount != 1 ? 's' : ''} • ${_formatDate(folder.createdAt)}',
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
    await _loadFolderTexts(folder.path);
  }

  Future<void> _shareFolder(ExtractedFolder folder) async {
    try {
      final dir = Directory(folder.path);
      final files = <XFile>[];

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          files.add(XFile(entity.path));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Extracted Text Files',
            files: files,
            subject: 'Extracted Text: ${folder.name}',
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
          'This will delete "${folder.name}" and all extracted text files. This action cannot be undone.',
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

  Widget _buildTextList(bool isCompact) {
    final displayTexts = _filteredTexts;

    if (displayTexts.isEmpty && !_isLoading) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No Results',
          subtitle: 'No text matches "$_searchQuery"',
        );
      }
      return _buildEmptyState(
        icon: Icons.text_snippet_outlined,
        title: 'No Extracted Text',
        subtitle: widget.hasFile
            ? 'Tap "Extract All" to extract text from pages'
            : 'Select a folder to view extracted text',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: displayTexts.length,
      itemBuilder: (context, index) {
        final textInfo = displayTexts[index];
        return _buildTextCard(textInfo, index, isCompact);
      },
    );
  }

  Widget _buildTextCard(ExtractedTextInfo textInfo, int index, bool isCompact) {
    final hasText = textInfo.text.isNotEmpty;
    final previewText = hasText
        ? (textInfo.text.length > 150
              ? '${textInfo.text.substring(0, 150)}...'
              : textInfo.text)
        : 'No text extracted';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: isCompact ? 36 : 40,
          height: isCompact ? 36 : 40,
          decoration: BoxDecoration(
            color: hasText
                ? Theme.of(context).primaryColor
                : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: hasText
                ? Text(
                    '${textInfo.pageNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  )
                : Icon(
                    Icons.text_snippet_outlined,
                    color: Colors.grey.shade500,
                    size: isCompact ? 16 : 18,
                  ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Page ${textInfo.pageNumber}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            if (!hasText && widget.hasFile) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _extractSinglePageText(textInfo.pageNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Extract',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          hasText ? '${textInfo.charCount} characters' : 'Not extracted',
          style: TextStyle(
            fontSize: isCompact ? 11 : 12,
            color: hasText ? null : Colors.orange,
          ),
        ),
        trailing: hasText
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
                onSelected: (value) =>
                    _handleTextMenuAction(value, textInfo, index),
                itemBuilder: (context) => [
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
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18),
                        SizedBox(width: 12),
                        Text('Copy'),
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
                  if (textInfo.filePath != null) ...[
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
                ],
              )
            : null,
        children: [
          if (hasText)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    textInfo.text,
                    style: TextStyle(
                      fontSize: isCompact ? 13 : 14,
                      height: 1.5,
                    ),
                    maxLines: 20,
                  ),
                  if (textInfo.text.length > 500) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => _showFullText(textInfo),
                        child: const Text('View Full Text'),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.copy,
                        label: 'Copy',
                        onTap: () => _copyText(textInfo),
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () => _shareText(textInfo),
                      ),
                      if (widget.onPageSelected != null)
                        _buildActionButton(
                          icon: Icons.visibility,
                          label: 'View',
                          onTap: () =>
                              widget.onPageSelected!(textInfo.pageNumber),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _handleTextMenuAction(
    String action,
    ExtractedTextInfo textInfo,
    int index,
  ) {
    switch (action) {
      case 'goto':
        widget.onPageSelected?.call(textInfo.pageNumber);
        break;
      case 'copy':
        _copyText(textInfo);
        break;
      case 'share':
        _shareText(textInfo);
        break;
      case 'properties':
        _showProperties(textInfo);
        break;
      case 'delete':
        _confirmDelete(textInfo, index);
        break;
    }
  }

  void _copyText(ExtractedTextInfo textInfo) {
    Clipboard.setData(ClipboardData(text: textInfo.text));
    _showSuccess('Text copied to clipboard');
  }

  void _shareText(ExtractedTextInfo textInfo) async {
    try {
      if (textInfo.filePath != null) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Extracted Text',
            files: [XFile(textInfo.filePath!)],
            subject: 'Page ${textInfo.pageNumber} Text',
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Extracted Text',
            text: textInfo.text,
            subject: 'Page ${textInfo.pageNumber} Text',
          ),
        );
      }
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  void _showFullText(ExtractedTextInfo textInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Page ${textInfo.pageNumber} Text'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyText(textInfo),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareText(textInfo),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              textInfo.text,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }

  void _showProperties(ExtractedTextInfo textInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Page ${textInfo.pageNumber} Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page', '${textInfo.pageNumber}'),
            _buildPropertyRow('Characters', '${textInfo.charCount}'),
            _buildPropertyRow(
              'Words',
              '${textInfo.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length}',
            ),
            _buildPropertyRow('Extracted', _formatDate(textInfo.extractedAt)),
            if (textInfo.filePath != null)
              _buildPropertyRow('Path', textInfo.filePath!),
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

  void _confirmDelete(ExtractedTextInfo textInfo, int index) async {
    if (textInfo.filePath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Extracted Text?'),
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

    if (confirmed == true) {
      await ref
          .read(pdfStateProvider.notifier)
          .deleteExtractedItem(textInfo.filePath!);

      if (widget.hasFile) {
        setState(() {
          _texts[index] = ExtractedTextInfo(
            pageNumber: textInfo.pageNumber,
            text: '',
            filePath: null,
            extractedAt: DateTime.now(),
          );
        });
      } else {
        setState(() {
          _texts.removeAt(index);
        });
      }

      _showSuccess('Text deleted');
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

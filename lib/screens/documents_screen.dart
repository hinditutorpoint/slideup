import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/media_provider.dart';
import '../widgets/media_item_card.dart';
import '../widgets/empty_state_widget.dart';
import 'pdf_viewer_screen.dart';
import 'package:open_filex/open_filex.dart';
import '../services/settings_service.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  late bool _isGridView;
  String _sortBy = 'name';
  DocumentType? _filterType;

  @override
  void initState() {
    super.initState();
    _isGridView = SettingsService.instance.isGridView;
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsProvider);

    return documents.when(
      data: (files) {
        if (files.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.description_outlined,
            title: 'No Documents',
            message: 'No documents found on your device',
          );
        }

        var filteredFiles = _filterType != null
            ? files.where((f) => f.documentType == _filterType).toList()
            : files;

        final sortedFiles = _sortFiles(filteredFiles);

        return Column(
          children: [
            _buildHeader(sortedFiles.length),
            _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(mediaProvider.notifier).scanMedia();
                },
                child: _isGridView
                    ? _buildGridView(sortedFiles)
                    : _buildListView(sortedFiles),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  List<MediaFile> _sortFiles(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        sorted.sort((a, b) => b.dateModified.compareTo(a.dateModified));
        break;
      case 'size':
        sorted.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return sorted;
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'document' : 'documents'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              const PopupMenuItem(value: 'size', child: Text('Sort by Size')),
            ],
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              SettingsService.instance.setIsGridView(_isGridView);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _filterType == null,
            onSelected: (selected) {
              setState(() => _filterType = null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('PDF'),
            selected: _filterType == DocumentType.pdf,
            onSelected: (selected) {
              setState(() => _filterType = selected ? DocumentType.pdf : null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Word'),
            selected: _filterType == DocumentType.word,
            onSelected: (selected) {
              setState(() => _filterType = selected ? DocumentType.word : null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Excel'),
            selected: _filterType == DocumentType.excel,
            onSelected: (selected) {
              setState(
                () => _filterType = selected ? DocumentType.excel : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('PowerPoint'),
            selected: _filterType == DocumentType.powerpoint,
            onSelected: (selected) {
              setState(
                () => _filterType = selected ? DocumentType.powerpoint : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<MediaFile> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return MediaItemCard(
          mediaFile: files[index],
          onTap: () => _openDocument(files, index),
        );
      },
    );
  }

  Widget _buildListView(List<MediaFile> files) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return MediaItemCard(
          mediaFile: files[index],
          isListView: true,
          onTap: () => _openDocument(files, index),
        );
      },
    );
  }

  void _openDocument(List<MediaFile> files, int index) async {
    final file = files[index];

    // Async side-effect FIRST
    await ref.read(mediaProvider.notifier).addToRecent(file);

    if (!mounted) return;

    if (file.documentType == DocumentType.pdf) {
      final pdfFiles = files
          .where((f) => f.documentType == DocumentType.pdf)
          .toList();

      final pdfIndex = pdfFiles.indexOf(file);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(
            mediaFile: file,
            playlist: pdfFiles,
            currentIndex: pdfIndex,
          ),
        ),
      );
    } else {
      // External app opening does NOT need BuildContext
      await OpenFilex.open(file.path);
    }
  }
}

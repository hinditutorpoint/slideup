import 'package:flutter/material.dart';
import 'dart:io';
import '../services/file_operations_service.dart';

class FileOperationsWidget extends StatefulWidget {
  final List<FileSystemEntity> selectedFiles;
  final VoidCallback onOperationComplete;
  final String? currentPath;

  const FileOperationsWidget({
    super.key,
    required this.selectedFiles,
    required this.onOperationComplete,
    this.currentPath,
  });

  @override
  State<FileOperationsWidget> createState() => _FileOperationsWidgetState();
}

class _FileOperationsWidgetState extends State<FileOperationsWidget> {
  final _service = FileOperationsService.instance;
  bool _isProcessing = false;
  String _currentOperation = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _service.onProgress = _updateProgress;
  }

  void _updateProgress(int current, int total, String currentFile) {
    if (mounted) {
      setState(() {
        _progress = total > 0 ? current / total : 0.0;
        _currentOperation = 'Processing: $currentFile';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasClipboard = _service.hasClipboard;
    final hasSelectedFiles = widget.selectedFiles.isNotEmpty;
    final isProcessing = _isProcessing;

    return Column(
      children: [
        if (hasClipboard) ...[
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  _service.currentOperation == FileOperation.copy
                      ? Icons.copy
                      : Icons.cut,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_service.getClipboardInfo())),
                TextButton(
                  onPressed: isProcessing ? null : _pasteFiles,
                  child: const Text('PASTE'),
                ),
                IconButton(
                  onPressed: _service.clearClipboard,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
        ],
        if (isProcessing) ...[
          LinearProgressIndicator(value: _progress),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_currentOperation),
          ),
        ],
        // Operation buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: isProcessing || !hasSelectedFiles
                    ? null
                    : _copyFiles,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing || !hasSelectedFiles ? null : _cutFiles,
                icon: const Icon(Icons.cut),
                label: const Text('Cut'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing || !hasSelectedFiles
                    ? null
                    : _duplicateFiles,
                icon: const Icon(Icons.file_copy),
                label: const Text('Duplicate'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing || !hasSelectedFiles
                    ? null
                    : _shareFiles,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing || !hasSelectedFiles
                    ? null
                    : _deleteFiles,
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyFiles() async {
    final result = await _service.copyFiles(widget.selectedFiles);
    if (result) {
      _showMessage('${widget.selectedFiles.length} items copied to clipboard');
    } else {
      _showError('Failed to copy files');
    }
  }

  Future<void> _cutFiles() async {
    final result = await _service.cutFiles(widget.selectedFiles);
    if (result) {
      _showMessage('${widget.selectedFiles.length} items cut to clipboard');
    } else {
      _showError('Failed to cut files');
    }
  }

  Future<void> _pasteFiles() async {
    final currentPath = widget.currentPath;
    if (currentPath == null) {
      _showError('No destination path available');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await _service.pasteFiles(currentPath);

      setState(() => _isProcessing = false);

      if (result.success) {
        _showMessage('Successfully pasted ${result.processedCount} items');
        widget.onOperationComplete();
      } else {
        final error = result.error;
        _showError(error ?? 'Paste operation failed');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Paste operation failed: $e');
    }
  }

  Future<void> _duplicateFiles() async {
    setState(() => _isProcessing = true);

    try {
      final result = await _service.duplicateFiles(widget.selectedFiles);

      setState(() => _isProcessing = false);

      if (result.success) {
        _showMessage('Successfully duplicated ${result.processedCount} items');
        widget.onOperationComplete();
      } else {
        final error = result.error;
        _showError(error ?? 'Duplicate operation failed');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Duplicate operation failed: $e');
    }
  }

  Future<void> _shareFiles() async {
    setState(() => _isProcessing = true);

    try {
      final result = await _service.shareFiles(widget.selectedFiles);

      setState(() => _isProcessing = false);

      if (result.success) {
        _showMessage('Successfully shared ${result.processedCount} items');
      } else {
        final error = result.error;
        _showError(error ?? 'Share operation failed');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Share operation failed: $e');
    }
  }

  Future<void> _deleteFiles() async {
    final confirmed = await _showDeleteConfirmation();
    final userConfirmed = confirmed == true;

    if (!userConfirmed) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _service.deleteFiles(widget.selectedFiles);

      setState(() => _isProcessing = false);

      if (result.success) {
        _showMessage('Successfully deleted ${result.processedCount} items');
        widget.onOperationComplete();
      } else {
        final error = result.error;
        _showError(error ?? 'Delete operation failed');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Delete operation failed: $e');
    }
  }

  Future<bool?> _showDeleteConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text(
          'Are you sure you want to delete ${widget.selectedFiles.length} items? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _service.onProgress = null;
    super.dispose();
  }
}

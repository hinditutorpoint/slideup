import 'package:flutter/material.dart';
import 'dart:io';
import '../services/thumbnail_service.dart';
import 'pdf/pdf_password_dialog.dart';

class PdfThumbnailPreviewDialog extends StatefulWidget {
  final String pdfPath;

  const PdfThumbnailPreviewDialog({super.key, required this.pdfPath});

  @override
  State<PdfThumbnailPreviewDialog> createState() =>
      _PdfThumbnailPreviewDialogState();
}

class _PdfThumbnailPreviewDialogState extends State<PdfThumbnailPreviewDialog> {
  List<String> _thumbnails = [];
  Map<String, dynamic>? _pdfInfo;
  bool _isLoading = true;
  bool _isPasswordProtected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdfThumbnails();
  }

  Future<void> _loadPdfThumbnails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if PDF is password protected
      final isProtected = await ThumbnailService.instance
          .isPdfPasswordProtected(widget.pdfPath);

      if (isProtected) {
        setState(() {
          _isPasswordProtected = true;
          _isLoading = false;
        });
        await _handlePasswordProtectedPdf();
        return;
      }

      await _generateThumbnails();
    } catch (e) {
      debugPrint('Error loading PDF thumbnails: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePasswordProtectedPdf() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) =>
          PdfPasswordDialog(fileName: widget.pdfPath.split('/').last),
    );

    if (password != null && mounted) {
      await _generateThumbnailsWithPassword(password);
    } else if (mounted) {
      setState(() {
        _error = 'Password required to view PDF';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateThumbnails() async {
    try {
      final thumbnails = await ThumbnailService.instance
          .generatePdfPageThumbnails(pdfPath: widget.pdfPath, maxPages: 5);

      final info = await ThumbnailService.instance.getPdfInfo(widget.pdfPath);

      if (mounted) {
        setState(() {
          _thumbnails = thumbnails;
          _pdfInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate thumbnails: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateThumbnailsWithPassword(String password) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Generate thumbnails with password
      final thumbnails = <String>[];
      for (int i = 0; i < 5; i++) {
        final thumbnail = await ThumbnailService.instance
            .generatePdfThumbnailWithPassword(
              pdfPath: widget.pdfPath,
              password: password,
              pageIndex: i,
            );
        if (thumbnail != null) {
          thumbnails.add(thumbnail);
        } else {
          break; // No more pages
        }
      }

      final info = await ThumbnailService.instance.getPdfInfo(widget.pdfPath);

      if (mounted) {
        setState(() {
          _thumbnails = thumbnails;
          _pdfInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid password or failed to load PDF';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF Preview'),
      content: SizedBox(width: 300, height: 400, child: _buildContent()),
      actions: [
        if (_isPasswordProtected && _error != null)
          TextButton(
            onPressed: () => _handlePasswordProtectedPdf(),
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pdfInfo != null) ...[
          Text('Pages: ${_pdfInfo!['pageCount'] ?? 'Unknown'}'),
          if (_pdfInfo!['title'] != null &&
              _pdfInfo!['title'].toString().isNotEmpty)
            Text('Title: ${_pdfInfo!['title']}'),
          const SizedBox(height: 16),
        ],
        if (_thumbnails.isNotEmpty) ...[
          const Text(
            'Page Preview:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: _thumbnails.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(_thumbnails[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error, color: Colors.red),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ] else ...[
          const Center(child: Text('No thumbnails available')),
        ],
      ],
    );
  }
}

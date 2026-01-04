import 'dart:io';

import 'package:flutter/material.dart';
import '../utils/reader_utils.dart';
import 'enhanced_pdf_reader.dart';
import '../../txt_reader/screens/text_downloads_screen.dart';
import '../../epub_reader/downloaded_epub_catalogue.dart';

class UnifiedReaderScreen extends StatefulWidget {
  final String documentUrl;
  final String title;
  final String? identifier;
  final String? thumbnailUrl;
  final int? initialPage;
  final String? initialChapter;
  final String? source;
  final DocumentType? forceType;

  const UnifiedReaderScreen({
    super.key,
    required this.documentUrl,
    required this.title,
    this.identifier,
    this.thumbnailUrl,
    this.source = 'web',
    this.initialPage,
    this.initialChapter,
    this.forceType,
  });

  @override
  State<UnifiedReaderScreen> createState() => _UnifiedReaderScreenState();
}

class _UnifiedReaderScreenState extends State<UnifiedReaderScreen> {
  DocumentType? _documentType;
  bool _isDetecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detectDocumentType();
  }

  Future<void> _detectDocumentType() async {
    setState(() {
      _isDetecting = true;
      _error = null;
    });

    try {
      if (widget.forceType != null) {
        _documentType = widget.forceType;
      } else {
        _documentType = DocumentUtils.detectDocumentType(widget.documentUrl);

        // If unknown, try to detect from content-type header
        if (_documentType == DocumentType.unknown) {
          _documentType = await _detectFromHeaders();
        }
      }

      if (_documentType == DocumentType.unknown) {
        _error = 'Unable to determine document type';
      }
    } catch (e) {
      _error = 'Error detecting document type: $e';
      debugPrint('⚠️ Detection error: $e');
    }

    if (mounted) {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  Future<DocumentType> _detectFromHeaders() async {
    try {
      final uri = Uri.parse(widget.documentUrl);
      if (uri.host.contains('archive.org')) {
        return DocumentType.pdf;
      }
    } catch (e) {
      debugPrint('⚠️ Header detection error: $e');
    }
    return DocumentType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDetecting) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Detecting document type...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _documentType == DocumentType.unknown) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unknown document type',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Go Back'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openAs(DocumentType.pdf),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Open as PDF'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openAs(DocumentType.epub),
                      icon: const Icon(Icons.book),
                      label: const Text('Open as EPUB'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openAs(DocumentType.txt),
                      icon: const Icon(Icons.text_snippet),
                      label: const Text('Open as Text'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildReader();
  }

  void _openAs(DocumentType type) {
    setState(() {
      _documentType = type;
      _error = null;
    });
  }

  Widget _buildReader() {
    switch (_documentType!) {
      case DocumentType.pdf:
        if (widget.source == 'local') {
          return EnhancedPdfReader(
            localFile: File(widget.documentUrl),
            title: widget.title,
            identifier: widget.identifier,
            initialPage: widget.initialPage,
          );
        } else {
          return EnhancedPdfReader(
            pdfUrl: widget.documentUrl,
            title: widget.title,
            identifier: widget.identifier,
            initialPage: widget.initialPage,
          );
        }
      case DocumentType.epub:
        if (widget.source == 'local') {
          return DownloadedEpubCatalogue(
            localFilePath: widget.documentUrl,
            bookTitle: widget.title,
            coverUrl: widget.thumbnailUrl,
          );
        } else {
          return DownloadedEpubCatalogue(
            url: widget.documentUrl,
            bookTitle: widget.title,
            coverUrl: widget.thumbnailUrl,
          );
        }
      case DocumentType.txt:
        return TextDownloadsScreen(
          url: widget.documentUrl,
          title: widget.title,
        );
      case DocumentType.unknown:
        return const SizedBox.shrink(); // Should not reach here
    }
  }
}

/// Helper widget to open documents from anywhere in the app
class DocumentOpener {
  static void open(
    BuildContext context, {
    required String url,
    required String title,
    String? identifier,
    int? initialPage,
    String? initialChapter,
    DocumentType? forceType,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedReaderScreen(
          documentUrl: url,
          title: title,
          identifier: identifier,
          initialPage: initialPage,
          initialChapter: initialChapter,
          forceType: forceType,
        ),
      ),
    );
  }

  static void openPdf(
    BuildContext context, {
    required String url,
    required String title,
    String? identifier,
    int? initialPage,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedPdfReader(
          pdfUrl: url,
          title: title,
          identifier: identifier,
          initialPage: initialPage,
        ),
      ),
    );
  }

  static void openEpub(
    BuildContext context, {
    required String url,
    required String title,
    String? identifier,
    String? initialChapter,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadedEpubCatalogue(
          url: url,
          bookTitle: title,
          coverUrl: 'https://example.com/cover.jpg',
        ),
      ),
    );
  }

  static void openTxt(
    BuildContext context, {
    required String url,
    required String title,
    String? identifier,
    int? initialPosition,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextDownloadsScreen(url: url, title: title),
      ),
    );
  }
}

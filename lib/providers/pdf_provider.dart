import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// ==================== STATE CLASSES ====================

class PdfState {
  final String? filePath;
  final String? fileName;
  final int currentPage;
  final int pageCount;
  final Set<int> bookmarks;
  final Map<int, List<HighlightInfo>> highlights;
  final Color currentHighlightColor;
  final bool isLoading;
  final String? loadingMessage;
  final String? error;
  final double loadingProgress;

  const PdfState({
    this.filePath,
    this.fileName,
    this.currentPage = 1,
    this.pageCount = 0,
    this.bookmarks = const {},
    this.highlights = const {},
    this.currentHighlightColor = Colors.yellow,
    this.isLoading = false,
    this.loadingMessage,
    this.error,
    this.loadingProgress = 0,
  });

  PdfState copyWith({
    String? filePath,
    String? fileName,
    int? currentPage,
    int? pageCount,
    Set<int>? bookmarks,
    Map<int, List<HighlightInfo>>? highlights,
    Color? currentHighlightColor,
    bool? isLoading,
    String? loadingMessage,
    String? error,
    double? loadingProgress,
  }) {
    return PdfState(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      currentPage: currentPage ?? this.currentPage,
      pageCount: pageCount ?? this.pageCount,
      bookmarks: bookmarks ?? this.bookmarks,
      highlights: highlights ?? this.highlights,
      currentHighlightColor:
          currentHighlightColor ?? this.currentHighlightColor,
      isLoading: isLoading ?? this.isLoading,
      loadingMessage: loadingMessage,
      error: error,
      loadingProgress: loadingProgress ?? this.loadingProgress,
    );
  }

  String get safeFolderName {
    if (fileName == null) return 'unknown';
    return fileName!
        .replaceAll('.pdf', '')
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .trim();
  }
}

class HighlightInfo {
  final int pageNumber;
  final Color color;
  final DateTime timestamp;
  final String text;
  final String id;

  HighlightInfo({
    required this.pageNumber,
    required this.color,
    required this.timestamp,
    required this.text,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'color': color.value,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'id': id,
  };

  factory HighlightInfo.fromJson(Map<String, dynamic> json) => HighlightInfo(
    pageNumber: json['pageNumber'] as int,
    color: Color(json['color'] as int),
    timestamp: DateTime.parse(json['timestamp'] as String),
    text: json['text'] as String,
    id: json['id'] as String?,
  );
}

class ExtractedFolder {
  final String name;
  final String path;
  final DateTime createdAt;
  final int itemCount;
  final ExtractedType type;

  ExtractedFolder({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.itemCount,
    required this.type,
  });
}

class ExtractedPageInfo {
  final int pageNumber;
  final String filePath;
  final DateTime extractedAt;
  final int fileSize;
  final String? thumbnailPath;

  ExtractedPageInfo({
    required this.pageNumber,
    required this.filePath,
    required this.extractedAt,
    required this.fileSize,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'filePath': filePath,
    'extractedAt': extractedAt.toIso8601String(),
    'fileSize': fileSize,
    'thumbnailPath': thumbnailPath,
  };

  factory ExtractedPageInfo.fromJson(Map<String, dynamic> json) =>
      ExtractedPageInfo(
        pageNumber: json['pageNumber'] as int,
        filePath: json['filePath'] as String,
        extractedAt: DateTime.parse(json['extractedAt'] as String),
        fileSize: json['fileSize'] as int,
        thumbnailPath: json['thumbnailPath'] as String?,
      );
}

class ExtractedTextInfo {
  final int pageNumber;
  final String text;
  final String? filePath;
  final DateTime extractedAt;
  final int charCount;

  ExtractedTextInfo({
    required this.pageNumber,
    required this.text,
    this.filePath,
    required this.extractedAt,
    int? charCount,
  }) : charCount = charCount ?? text.length;

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'text': text,
    'filePath': filePath,
    'extractedAt': extractedAt.toIso8601String(),
    'charCount': charCount,
  };

  factory ExtractedTextInfo.fromJson(Map<String, dynamic> json) =>
      ExtractedTextInfo(
        pageNumber: json['pageNumber'] as int,
        text: (json['text'] as String?) ?? '',
        filePath: json['filePath'] as String?,
        extractedAt: DateTime.parse(json['extractedAt'] as String),
        charCount: json['charCount'] as int?,
      );
}

class ExtractedImageInfo {
  final int pageNumber;
  final int imageIndex;
  final Uint8List? imageData;
  final String? filePath;
  final DateTime extractedAt;
  final int width;
  final int height;
  final int fileSize;

  ExtractedImageInfo({
    required this.pageNumber,
    required this.imageIndex,
    this.imageData,
    this.filePath,
    required this.extractedAt,
    required this.width,
    required this.height,
    this.fileSize = 0,
  });

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'imageIndex': imageIndex,
    'filePath': filePath,
    'extractedAt': extractedAt.toIso8601String(),
    'width': width,
    'height': height,
    'fileSize': fileSize,
  };

  factory ExtractedImageInfo.fromJson(Map<String, dynamic> json) =>
      ExtractedImageInfo(
        pageNumber: json['pageNumber'] as int,
        imageIndex: json['imageIndex'] as int,
        filePath: json['filePath'] as String?,
        extractedAt: DateTime.parse(json['extractedAt'] as String),
        width: (json['width'] as int?) ?? 0,
        height: (json['height'] as int?) ?? 0,
        fileSize: (json['fileSize'] as int?) ?? 0,
      );
}

enum ExtractedType { pages, text, images }

// ==================== NOTIFIER ====================

class PdfStateNotifier extends Notifier<PdfState> {
  @override
  PdfState build() {
    return const PdfState();
  }

  static const String _extractedRootFolder = 'SlideUp_Extracted';

  void loadDocument(String filePath, String fileName) {
    state = PdfState(
      filePath: filePath,
      fileName: fileName,
      bookmarks: {},
      highlights: {},
    );
  }

  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setPageCount(int count) {
    state = state.copyWith(pageCount: count);
  }

  void setLoading(bool loading, {String? message, double progress = 0}) {
    state = state.copyWith(
      isLoading: loading,
      loadingMessage: message,
      loadingProgress: progress,
    );
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ==================== BOOKMARKS ====================

  void toggleBookmark(int pageNumber) {
    final bookmarks = Set<int>.from(state.bookmarks);
    if (bookmarks.contains(pageNumber)) {
      bookmarks.remove(pageNumber);
    } else {
      bookmarks.add(pageNumber);
    }
    state = state.copyWith(bookmarks: bookmarks);
  }

  void removeBookmark(int pageNumber) {
    final bookmarks = Set<int>.from(state.bookmarks);
    bookmarks.remove(pageNumber);
    state = state.copyWith(bookmarks: bookmarks);
  }

  void clearAllBookmarks() {
    state = state.copyWith(bookmarks: {});
  }

  // ==================== HIGHLIGHTS ====================

  void setHighlightColor(Color color) {
    state = state.copyWith(currentHighlightColor: color);
  }

  void addHighlight({required int pageNumber, required String text}) {
    final highlights = Map<int, List<HighlightInfo>>.from(
      state.highlights.map((key, value) => MapEntry(key, List.from(value))),
    );

    final highlight = HighlightInfo(
      pageNumber: pageNumber,
      color: state.currentHighlightColor,
      timestamp: DateTime.now(),
      text: text,
    );

    if (!highlights.containsKey(pageNumber)) {
      highlights[pageNumber] = [];
    }
    highlights[pageNumber] = [...highlights[pageNumber]!, highlight];
    state = state.copyWith(highlights: highlights);
  }

  void removeHighlight(int pageNumber, String highlightId) {
    final highlights = Map<int, List<HighlightInfo>>.from(
      state.highlights.map((key, value) => MapEntry(key, List.from(value))),
    );

    if (highlights.containsKey(pageNumber)) {
      highlights[pageNumber] = highlights[pageNumber]!
          .where((h) => h.id != highlightId)
          .toList();
      if (highlights[pageNumber]!.isEmpty) {
        highlights.remove(pageNumber);
      }
    }
    state = state.copyWith(highlights: highlights);
  }

  void clearPageHighlights(int pageNumber) {
    final highlights = Map<int, List<HighlightInfo>>.from(
      state.highlights.map((key, value) => MapEntry(key, List.from(value))),
    );
    highlights.remove(pageNumber);
    state = state.copyWith(highlights: highlights);
  }

  void clearAllHighlights() {
    state = state.copyWith(highlights: {});
  }

  // ==================== DIRECTORY MANAGEMENT ====================

  Future<String> getExtractionBaseDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final extractDir = Directory('${appDir.path}/$_extractedRootFolder');
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }
    return extractDir.path;
  }

  Future<String> getExtractionDirectory(ExtractedType type) async {
    final baseDir = await getExtractionBaseDirectory();
    final folderName = state.safeFolderName;
    String typePath;

    switch (type) {
      case ExtractedType.pages:
        typePath = 'pages';
        break;
      case ExtractedType.text:
        typePath = 'text';
        break;
      case ExtractedType.images:
        typePath = 'images';
        break;
    }

    final extractDir = Directory('$baseDir/$folderName/$typePath');
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }
    return extractDir.path;
  }

  Future<List<ExtractedFolder>> getExtractedFolders(ExtractedType type) async {
    final baseDir = await getExtractionBaseDirectory();
    final baseDirEntity = Directory(baseDir);

    if (!await baseDirEntity.exists()) {
      return [];
    }

    List<ExtractedFolder> folders = [];
    String typePath;

    switch (type) {
      case ExtractedType.pages:
        typePath = 'pages';
        break;
      case ExtractedType.text:
        typePath = 'text';
        break;
      case ExtractedType.images:
        typePath = 'images';
        break;
    }

    await for (final entity in baseDirEntity.list()) {
      if (entity is Directory) {
        final typeDir = Directory('${entity.path}/$typePath');
        if (await typeDir.exists()) {
          int itemCount = 0;
          await for (final _ in typeDir.list()) {
            itemCount++;
          }

          if (itemCount > 0) {
            final stat = await entity.stat();
            folders.add(
              ExtractedFolder(
                name: path.basename(entity.path),
                path: typeDir.path,
                createdAt: stat.modified,
                itemCount: itemCount,
                type: type,
              ),
            );
          }
        }
      }
    }

    folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return folders;
  }

  Future<List<ExtractedPageInfo>> getExtractedPagesFromFolder(
    String folderPath,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    List<ExtractedPageInfo> pages = [];

    // Try to load from metadata first
    final metaFile = File('$folderPath/metadata.json');
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        pages = jsonList
            .map((e) => ExtractedPageInfo.fromJson(e as Map<String, dynamic>))
            .toList();

        // Verify files still exist
        pages = pages.where((p) => File(p.filePath).existsSync()).toList();

        if (pages.isNotEmpty) {
          pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
          return pages;
        }
      } catch (e) {
        debugPrint('Error loading metadata: $e');
      }
    }

    // Scan directory if metadata not available
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
          final fileName = path.basenameWithoutExtension(entity.path);
          final pageMatch = RegExp(r'page_(\d+)').firstMatch(fileName);
          if (pageMatch != null) {
            final stat = await entity.stat();
            pages.add(
              ExtractedPageInfo(
                pageNumber: int.parse(pageMatch.group(1)!),
                filePath: entity.path,
                extractedAt: stat.modified,
                fileSize: stat.size,
              ),
            );
          }
        }
      }
    }

    pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return pages;
  }

  Future<List<ExtractedTextInfo>> getExtractedTextsFromFolder(
    String folderPath,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    List<ExtractedTextInfo> texts = [];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        final fileName = path.basenameWithoutExtension(entity.path);

        // Skip full_text.txt
        if (fileName == 'full_text') continue;

        final pageMatch = RegExp(r'page_(\d+)').firstMatch(fileName);
        if (pageMatch != null) {
          try {
            final stat = await entity.stat();
            final content = await entity.readAsString();
            texts.add(
              ExtractedTextInfo(
                pageNumber: int.parse(pageMatch.group(1)!),
                text: content,
                filePath: entity.path,
                extractedAt: stat.modified,
              ),
            );
          } catch (e) {
            debugPrint('Error reading text file: $e');
          }
        }
      }
    }

    texts.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return texts;
  }

  Future<List<ExtractedImageInfo>> getExtractedImagesFromFolder(
    String folderPath,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    List<ExtractedImageInfo> images = [];

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
          final fileName = path.basenameWithoutExtension(entity.path);
          final match = RegExp(r'page_(\d+)_image_(\d+)').firstMatch(fileName);
          if (match != null) {
            try {
              final stat = await entity.stat();
              images.add(
                ExtractedImageInfo(
                  pageNumber: int.parse(match.group(1)!),
                  imageIndex: int.parse(match.group(2)!),
                  filePath: entity.path,
                  extractedAt: stat.modified,
                  width: 0,
                  height: 0,
                  fileSize: stat.size,
                ),
              );
            } catch (e) {
              debugPrint('Error reading image info: $e');
            }
          }
        }
      }
    }

    images.sort((a, b) {
      final pageCompare = a.pageNumber.compareTo(b.pageNumber);
      if (pageCompare != 0) return pageCompare;
      return a.imageIndex.compareTo(b.imageIndex);
    });

    return images;
  }

  // ==================== EXTRACTION METHODS ====================

  Future<List<ExtractedPageInfo>> extractAllPages({
    void Function(int current, int total)? onProgress,
  }) async {
    if (state.filePath == null) {
      throw Exception('No PDF file loaded');
    }

    setLoading(true, message: 'Extracting pages...');

    try {
      final bytes = await File(state.filePath!).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractDir = await getExtractionDirectory(ExtractedType.pages);

      List<ExtractedPageInfo> pages = [];
      final totalPages = document.pages.count;

      for (int i = 0; i < totalPages; i++) {
        onProgress?.call(i + 1, totalPages);
        setLoading(
          true,
          message: 'Extracting page ${i + 1} of $totalPages',
          progress: (i + 1) / totalPages,
        );

        final imagePath = '$extractDir/page_${i + 1}.png';
        final imageFile = File(imagePath);

        // Render page to image
        final imageBytes = await _renderPageToImage(document.pages[i], i + 1);
        await imageFile.writeAsBytes(imageBytes);

        final stat = await imageFile.stat();
        pages.add(
          ExtractedPageInfo(
            pageNumber: i + 1,
            filePath: imagePath,
            extractedAt: DateTime.now(),
            fileSize: stat.size,
          ),
        );
      }

      // Save metadata
      await _saveMetadata(extractDir, pages);

      document.dispose();
      setLoading(false);

      return pages;
    } catch (e) {
      setError('Failed to extract pages: $e');
      rethrow;
    }
  }

  Future<ExtractedPageInfo> extractSinglePage(int pageNumber) async {
    if (state.filePath == null) {
      throw Exception('No PDF file loaded');
    }

    if (pageNumber < 1 || pageNumber > state.pageCount) {
      throw Exception('Invalid page number: $pageNumber');
    }

    try {
      final bytes = await File(state.filePath!).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractDir = await getExtractionDirectory(ExtractedType.pages);

      final imagePath = '$extractDir/page_$pageNumber.png';
      final imageFile = File(imagePath);

      final imageBytes = await _renderPageToImage(
        document.pages[pageNumber - 1],
        pageNumber,
      );
      await imageFile.writeAsBytes(imageBytes);

      final stat = await imageFile.stat();
      final pageInfo = ExtractedPageInfo(
        pageNumber: pageNumber,
        filePath: imagePath,
        extractedAt: DateTime.now(),
        fileSize: stat.size,
      );

      document.dispose();
      return pageInfo;
    } catch (e) {
      setError('Failed to extract page: $e');
      rethrow;
    }
  }

  Future<List<ExtractedTextInfo>> extractAllText({
    void Function(int current, int total)? onProgress,
  }) async {
    if (state.filePath == null) {
      throw Exception('No PDF file loaded');
    }

    setLoading(true, message: 'Extracting text...');

    try {
      final bytes = await File(state.filePath!).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractDir = await getExtractionDirectory(ExtractedType.text);

      List<ExtractedTextInfo> texts = [];
      String fullText = '';
      final totalPages = document.pages.count;

      for (int i = 0; i < totalPages; i++) {
        onProgress?.call(i + 1, totalPages);
        setLoading(
          true,
          message: 'Extracting text from page ${i + 1} of $totalPages',
          progress: (i + 1) / totalPages,
        );

        final textExtractor = PdfTextExtractor(document);
        final pageText = textExtractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );

        final textPath = '$extractDir/page_${i + 1}.txt';
        final textFile = File(textPath);
        await textFile.writeAsString(pageText);

        texts.add(
          ExtractedTextInfo(
            pageNumber: i + 1,
            text: pageText,
            filePath: textPath,
            extractedAt: DateTime.now(),
          ),
        );

        fullText += '\n--- Page ${i + 1} ---\n$pageText\n';
      }

      // Save full text
      final fullTextFile = File('$extractDir/full_text.txt');
      await fullTextFile.writeAsString(fullText);

      document.dispose();
      setLoading(false);

      return texts;
    } catch (e) {
      setError('Failed to extract text: $e');
      rethrow;
    }
  }

  Future<ExtractedTextInfo> extractSinglePageText(int pageNumber) async {
    if (state.filePath == null) {
      throw Exception('No PDF file loaded');
    }

    if (pageNumber < 1 || pageNumber > state.pageCount) {
      throw Exception('Invalid page number: $pageNumber');
    }

    try {
      final bytes = await File(state.filePath!).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractDir = await getExtractionDirectory(ExtractedType.text);

      final textExtractor = PdfTextExtractor(document);
      final pageText = textExtractor.extractText(
        startPageIndex: pageNumber - 1,
        endPageIndex: pageNumber - 1,
      );

      final textPath = '$extractDir/page_$pageNumber.txt';
      final textFile = File(textPath);
      await textFile.writeAsString(pageText);

      document.dispose();

      return ExtractedTextInfo(
        pageNumber: pageNumber,
        text: pageText,
        filePath: textPath,
        extractedAt: DateTime.now(),
      );
    } catch (e) {
      setError('Failed to extract text: $e');
      rethrow;
    }
  }

  Future<void> deleteExtractedItem(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      setError('Failed to delete: $e');
      rethrow;
    }
  }

  Future<void> deleteExtractedFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // Check if parent folder is empty and delete if so
      final parentDir = dir.parent;
      if (await parentDir.exists()) {
        final contents = await parentDir.list().toList();
        if (contents.isEmpty) {
          await parentDir.delete();
        }
      }
    } catch (e) {
      setError('Failed to delete folder: $e');
      rethrow;
    }
  }

  Future<Uint8List> _renderPageToImage(PdfPage page, int pageNumber) async {
    final width = (page.size.width * 2).toInt();
    final height = (page.size.height * 2).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    // Draw page number in center (placeholder - actual rendering would need platform channels)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$pageNumber',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: height * 0.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _saveMetadata(String dir, List<ExtractedPageInfo> pages) async {
    try {
      final metaFile = File('$dir/metadata.json');
      final jsonList = pages.map((e) => e.toJson()).toList();
      await metaFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }
}

// ==================== PROVIDER ====================

final pdfStateProvider = NotifierProvider<PdfStateNotifier, PdfState>(
  () => PdfStateNotifier(),
);

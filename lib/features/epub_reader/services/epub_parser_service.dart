import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import '../../../core/utils/safe_async.dart';
import '../../../core/utils/memory_manager.dart';
import '../models/epub_book.dart';
import '../models/epub_chapter.dart';

/// Service for parsing EPUB files
class EpubParserService {
  EpubParserService._();

  static final EpubParserService _instance = EpubParserService._();
  static EpubParserService get instance => _instance;

  // Cache directory for extracted EPUB content
  String? _cacheDirectory;

  // Memory manager reference
  final MemoryManager _memoryManager = MemoryManager.instance;

  // Is service initialized
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize parser service
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = path.join(appDir.path, AppConstants.epubCacheDir);

      final cacheDir = Directory(_cacheDirectory!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      _isInitialized = true;
      debugPrint('EpubParserService initialized');
    }, operationName: 'EpubParserService.initialize');
  }

  /// Dispose service
  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('EpubParserService disposed');
  }

  // ===========================================================================
  // PARSING OPERATIONS
  // ===========================================================================

  /// Parse EPUB file and return book metadata
  Future<Result<EpubBook>> parseBook(String filePath) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();
      final drmCheck = _checkForDRM(bytes, filePath);
      if (drmCheck != null) {
        throw drmCheck;
      }
      // Run heavy parsing in a background isolate via Flutter's compute
      final book = await compute<_ParseEpubParams, EpubBook>(
        _parseEpubBytes,
        _ParseEpubParams(
          bytes: bytes,
          filePath: filePath,
          cacheDir: _cacheDirectory ?? '',
        ),
      );

      return book;
    }, operationName: 'parseBook');
  }

  EpubParseException? _checkForDRM(Uint8List bytes, String filePath) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Check for LCP DRM
      final hasLcpLicense = archive.findFile('META-INF/license.lcpl') != null;
      final hasLcpInName =
          filePath.toLowerCase().contains('_lcp') ||
          filePath.toLowerCase().contains('.lcp');

      if (hasLcpLicense || hasLcpInName) {
        debugPrint('❌ LCP DRM detected in: $filePath');
        return EpubParseException(
          message:
              'This EPUB is protected with LCP DRM and cannot be opened. Please use an LCP-compatible reader app.',
          code: 'LCP_DRM_PROTECTED',
        );
      }

      // Check for Adobe DRM
      final hasAdobeDrm = archive.findFile('META-INF/rights.xml') != null;
      if (hasAdobeDrm) {
        debugPrint('❌ Adobe DRM detected in: $filePath');
        return EpubParseException(
          message:
              'This EPUB is protected with Adobe DRM and cannot be opened. Please use Adobe Digital Editions.',
          code: 'ADOBE_DRM_PROTECTED',
        );
      }

      // Check for encryption.xml (general encryption)
      final encryptionFile = archive.findFile('META-INF/encryption.xml');
      if (encryptionFile != null) {
        final encryptionXml = utf8.decode(encryptionFile.content as List<int>);

        // Check if it's just font encryption (allowed) or content encryption (blocked)
        if (encryptionXml.contains('EncryptedData') &&
            !_isOnlyFontEncryption(encryptionXml)) {
          debugPrint('❌ Content encryption detected in: $filePath');
          return EpubParseException(
            message: 'This EPUB has encrypted content and cannot be opened.',
            code: 'CONTENT_ENCRYPTED',
          );
        }
      }

      return null; // No DRM detected
    } catch (e) {
      debugPrint('⚠️ Could not check DRM: $e');
      return null; // Continue anyway if check fails
    }
  }

  /// Check if encryption.xml only contains font encryption (which is okay)
  bool _isOnlyFontEncryption(String encryptionXml) {
    // Font obfuscation is common and doesn't prevent reading
    final hasFontEncryption =
        encryptionXml.contains('obfuscation') ||
        encryptionXml.contains('font') ||
        encryptionXml.contains('.otf') ||
        encryptionXml.contains('.ttf') ||
        encryptionXml.contains('.woff');

    // Check if there's content encryption (HTML/XHTML)
    final hasContentEncryption =
        encryptionXml.contains('.xhtml') ||
        encryptionXml.contains('.html') ||
        encryptionXml.contains('.htm');

    return hasFontEncryption && !hasContentEncryption;
  }

  /// Parse EPUB from bytes
  Future<Result<EpubBook>> parseBookFromBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final effectiveFileName = fileName ?? 'unknown.epub';

    return SafeAsync.run(() async {
      final book = await compute<_ParseEpubParams, EpubBook>(
        _parseEpubBytes,
        _ParseEpubParams(
          bytes: bytes,
          filePath: effectiveFileName,
          cacheDir: _cacheDirectory ?? '',
        ),
      );

      return book;
    }, operationName: 'parseBookFromBytes');
  }

  /// Extract and parse a specific chapter
  Future<Result<EpubChapter>> parseChapter({
    required String filePath,
    required int chapterIndex,
    required String chapterHref,
    required String bookId,
  }) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      // Check cache first
      final cacheKey = '${bookId}_chapter_$chapterIndex';
      final cachedContent = _memoryManager.getCachedChapter(cacheKey);
      if (cachedContent != null) {
        // Parse cached HTML content on main isolate
        return _parseChapterContent(
          htmlContent: cachedContent,
          chapterIndex: chapterIndex,
          chapterHref: chapterHref,
          bookId: bookId,
        );
      }

      // Extract chapter in background isolate
      final bytes = await file.readAsBytes();

      final chapter = await compute<_ExtractChapterParams, EpubChapter>(
        _extractChapterContent,
        _ExtractChapterParams(
          bytes: bytes,
          chapterHref: chapterHref,
          chapterIndex: chapterIndex,
          bookId: bookId,
        ),
      );

      // Cache the content
      _memoryManager.cacheChapter(cacheKey, chapter.htmlContent as String);

      return chapter;
    }, operationName: 'parseChapter');
  }

  /// Extract cover image from EPUB
  Future<Result<Uint8List?>> extractCover(String filePath) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();

      final coverBytes = await compute<Uint8List, Uint8List?>(
        _extractCoverImage,
        bytes,
      );

      return coverBytes;
    }, operationName: 'extractCover');
  }

  /// Extract all images from a chapter
  Future<Result<Map<String, Uint8List>>> extractChapterImages({
    required String filePath,
    required String chapterHref,
  }) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();

      final images =
          await compute<_ExtractImagesParams, Map<String, Uint8List>>(
            _extractImagesFromChapter,
            _ExtractImagesParams(bytes: bytes, chapterHref: chapterHref),
          );

      return images;
    }, operationName: 'extractChapterImages');
  }

  /// Get table of contents
  Future<Result<List<TocEntry>>> getTableOfContents(String filePath) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();

      final toc = await compute<Uint8List, List<TocEntry>>(
        _extractTableOfContents,
        bytes,
      );

      return toc;
    }, operationName: 'getTableOfContents');
  }

  /// Search text in EPUB
  Future<Result<List<SearchResult>>> searchInBook({
    required String filePath,
    required String query,
    bool caseSensitive = false,
    int maxResults = 100,
  }) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();

      final results = await compute<_SearchParams, List<SearchResult>>(
        _searchInEpub,
        _SearchParams(
          bytes: bytes,
          query: query,
          caseSensitive: caseSensitive,
          maxResults: maxResults,
        ),
      );

      return results;
    }, operationName: 'searchInBook');
  }

  /// Validate EPUB file
  Future<Result<EpubValidationResult>> validateEpub(String filePath) async {
    return SafeAsync.run(() async {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      final bytes = await file.readAsBytes();

      final validation = await compute<Uint8List, EpubValidationResult>(
        _validateEpubFile,
        bytes,
      );

      return validation;
    }, operationName: 'validateEpub');
  }

  /// Parse chapter content from HTML (on main isolate)
  EpubChapter _parseChapterContent({
    required String htmlContent,
    required int chapterIndex,
    required String chapterHref,
    required String bookId,
  }) {
    try {
      final document = html_parser.parse(htmlContent);
      final body = document.body;

      // Extract text content
      final textContent = body?.text ?? '';

      // Extract title from first heading
      String title = 'Chapter ${chapterIndex + 1}';
      final headings = body?.querySelectorAll('h1, h2, h3');
      if (headings != null && headings.isNotEmpty) {
        title = headings.first.text.trim();
        if (title.isEmpty) {
          title = 'Chapter ${chapterIndex + 1}';
        }
      }

      // Extract images
      final images = _extractImagesFromDocument(document, chapterHref);

      // Extract links
      final links = _extractLinksFromDocument(document);

      // Count words
      final wordCount = _countWords(textContent);

      return EpubChapter(
        id: 'chapter_${bookId}_$chapterIndex',
        title: title,
        index: chapterIndex,
        htmlContent: htmlContent,
        textContent: textContent,
        href: chapterHref,
        mediaType: 'application/xhtml+xml',
        wordCount: wordCount,
        characterCount: textContent.length,
        estimatedReadingMinutes: (wordCount / 200).ceil(),
        images: images,
        links: links,
        isLoaded: true,
        bookId: bookId,
      );
    } catch (e) {
      return EpubChapter(
        id: 'chapter_${bookId}_$chapterIndex',
        title: 'Chapter ${chapterIndex + 1}',
        index: chapterIndex,
        htmlContent: htmlContent,
        href: chapterHref,
        isLoaded: true,
        bookId: bookId,
      );
    }
  }

  /// Extract images from HTML document
  List<ChapterImage> _extractImagesFromDocument(
    html_dom.Document document,
    String chapterHref,
  ) {
    final images = <ChapterImage>[];
    final basePath = path.dirname(chapterHref);

    try {
      final imgElements = document.querySelectorAll('img');
      for (int i = 0; i < imgElements.length; i++) {
        final img = imgElements[i];
        final src = img.attributes['src'];
        if (src != null && src.isNotEmpty) {
          images.add(
            ChapterImage(
              id: 'img_${i}_${src.hashCode}',
              src: _resolveImagePath(src, basePath),
              alt: img.attributes['alt'],
              title: img.attributes['title'],
            ),
          );
        }
      }

      // Also check for SVG images
      final svgElements = document.querySelectorAll('svg image');
      for (int i = 0; i < svgElements.length; i++) {
        final svg = svgElements[i];
        final href = svg.attributes['xlink:href'] ?? svg.attributes['href'];
        if (href != null && href.isNotEmpty) {
          images.add(
            ChapterImage(
              id: 'svg_img_${i}_${href.hashCode}',
              src: _resolveImagePath(href, basePath),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error extracting images: $e');
    }

    return images;
  }

  /// Extract links from HTML document
  List<ChapterLink> _extractLinksFromDocument(html_dom.Document document) {
    final links = <ChapterLink>[];

    try {
      final anchorElements = document.querySelectorAll('a');
      for (final anchor in anchorElements) {
        final href = anchor.attributes['href'];
        if (href != null && href.isNotEmpty) {
          LinkType type;
          String? targetChapterId;
          String? anchorId;

          if (href.startsWith('http://') || href.startsWith('https://')) {
            type = LinkType.external;
          } else if (href.startsWith('#')) {
            type = LinkType.internal;
            anchorId = href.substring(1);
          } else if (href.contains('#')) {
            type = LinkType.internal;
            final parts = href.split('#');
            targetChapterId = parts[0];
            anchorId = parts.length > 1 ? parts[1] : null;
          } else {
            type = LinkType.internal;
            targetChapterId = href;
          }

          // Check for footnote patterns
          if (href.contains('note') ||
              href.contains('footnote') ||
              href.contains('fn')) {
            type = LinkType.footnote;
          }

          links.add(
            ChapterLink(
              href: href,
              text: anchor.text.trim(),
              type: type,
              targetChapterId: targetChapterId,
              anchor: anchorId,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error extracting links: $e');
    }

    return links;
  }

  /// Resolve image path relative to chapter
  String _resolveImagePath(String src, String basePath) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    if (src.startsWith('/')) {
      return src.substring(1);
    }
    return path.normalize(path.join(basePath, src));
  }

  /// Count words in text
  int _countWords(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  /// Clear parser cache
  Future<Result<void>> clearCache() async {
    return SafeAsync.run(() async {
      _memoryManager.clearChapterCache();

      if (_cacheDirectory != null) {
        final cacheDir = Directory(_cacheDirectory!);
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list()) {
            await entity.delete(recursive: true);
          }
        }
      }
    }, operationName: 'clearCache');
  }
}

// =============================================================================
// ISOLATE FUNCTIONS (Must be top-level)
// =============================================================================

/// Parameters for parsing EPUB
class _ParseEpubParams {
  final Uint8List bytes;
  final String filePath;
  final String cacheDir;

  _ParseEpubParams({
    required this.bytes,
    required this.filePath,
    required this.cacheDir,
  });
}

/// Parameters for extracting chapter
class _ExtractChapterParams {
  final Uint8List bytes;
  final String chapterHref;
  final int chapterIndex;
  final String bookId;

  _ExtractChapterParams({
    required this.bytes,
    required this.chapterHref,
    required this.chapterIndex,
    required this.bookId,
  });
}

/// Parameters for extracting images
class _ExtractImagesParams {
  final Uint8List bytes;
  final String chapterHref;

  _ExtractImagesParams({required this.bytes, required this.chapterHref});
}

/// Parameters for search
class _SearchParams {
  final Uint8List bytes;
  final String query;
  final bool caseSensitive;
  final int maxResults;

  _SearchParams({
    required this.bytes,
    required this.query,
    required this.caseSensitive,
    required this.maxResults,
  });
}

/// Parse EPUB bytes (runs in isolate)
EpubBook _parseEpubBytes(_ParseEpubParams params) {
  try {
    final archive = ZipDecoder().decodeBytes(params.bytes);

    // Find container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      throw EpubParseException.missingComponent(component: 'container.xml');
    }

    // Parse container.xml to find OPF file path
    final containerXml = utf8.decode(containerFile.content as List<int>);
    final opfPath = _extractOpfPath(containerXml);
    if (opfPath == null) {
      throw EpubParseException.missingComponent(component: 'OPF file path');
    }

    // Find and parse OPF file
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) {
      throw EpubParseException.missingComponent(component: opfPath);
    }

    final opfXml = utf8.decode(opfFile.content as List<int>);
    final opfBasePath = path.dirname(opfPath);

    // Parse metadata, manifest, spine
    final metadata = _parseOpfMetadata(opfXml);
    final manifest = _parseOpfManifest(opfXml, opfBasePath);
    final spine = _parseOpfSpine(opfXml, manifest);

    // Extract cover
    final coverPath = _findCoverPath(opfXml, manifest, opfBasePath);

    // Parse NCX for table of contents
    List<TocEntry>? toc;
    final ncxPath = manifest['ncx']?['href'];
    if (ncxPath != null) {
      final ncxFile = archive.findFile(ncxPath);
      if (ncxFile != null) {
        final ncxXml = utf8.decode(ncxFile.content as List<int>);
        toc = _parseNcx(ncxXml, path.dirname(ncxPath));
      }
    }

    // Build chapter metadata
    final chapters = <EpubChapterMeta>[];
    for (int i = 0; i < spine.length; i++) {
      final item = spine[i];
      chapters.add(
        EpubChapterMeta(
          id: item['id'] ?? 'chapter_$i',
          title: item['title'] ?? 'Chapter ${i + 1}',
          index: i,
          href: item['href'],
        ),
      );
    }

    // Generate deterministic book ID from file hash
    final bookId = _generateBookIdFromBytes(params.bytes);

    return EpubBook(
      id: bookId,
      title: metadata['title'] ?? 'Unknown Title',
      author: metadata['creator'],
      publisher: metadata['publisher'],
      description: metadata['description'],
      language: metadata['language'],
      isbn: metadata['identifier'],
      coverPath: coverPath,
      filePath: params.filePath,
      fileSize: params.bytes.length,
      chapterCount: chapters.length,
      chapters: chapters,
      subjects:
          (metadata['subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rights: metadata['rights'],
      epubVersion: metadata['version'],
      addedAt: DateTime.now(),
      isDownloaded: true,
      tableOfContents: toc,
      spine: spine.map((s) => s['href'] as String).toList(),
    );
  } catch (e) {
    if (e is EpubException) rethrow;
    throw EpubParseException.invalidFormat(
      filePath: params.filePath,
      originalError: e,
    );
  }
}

/// Generate deterministic book ID from file bytes using MD5 hash
String _generateBookIdFromBytes(Uint8List bytes) {
  // Use MD5 hash of file bytes for deterministic ID
  final hash = md5.convert(bytes);
  return 'book_${hash.toString()}';
}

/// Extract OPF path from container.xml
String? _extractOpfPath(String containerXml) {
  try {
    final match = RegExp(r'full-path="([^"]+)"').firstMatch(containerXml);
    return match?.group(1);
  } catch (_) {
    return null;
  }
}

/// Parse OPF metadata
Map<String, dynamic> _parseOpfMetadata(String opfXml) {
  final metadata = <String, dynamic>{};

  try {
    // Extract title
    final titleMatch = RegExp(
      r'<dc:title[^>]*>([^<]+)</dc:title>',
    ).firstMatch(opfXml);
    metadata['title'] = titleMatch?.group(1)?.trim();

    // Extract creator/author
    final creatorMatch = RegExp(
      r'<dc:creator[^>]*>([^<]+)</dc:creator>',
    ).firstMatch(opfXml);
    metadata['creator'] = creatorMatch?.group(1)?.trim();

    // Extract publisher
    final publisherMatch = RegExp(
      r'<dc:publisher[^>]*>([^<]+)</dc:publisher>',
    ).firstMatch(opfXml);
    metadata['publisher'] = publisherMatch?.group(1)?.trim();

    // Extract description
    final descMatch = RegExp(
      r'<dc:description[^>]*>([^<]+)</dc:description>',
    ).firstMatch(opfXml);
    metadata['description'] = descMatch?.group(1)?.trim();

    // Extract language
    final langMatch = RegExp(
      r'<dc:language[^>]*>([^<]+)</dc:language>',
    ).firstMatch(opfXml);
    metadata['language'] = langMatch?.group(1)?.trim();

    // Extract identifier
    final idMatch = RegExp(
      r'<dc:identifier[^>]*>([^<]+)</dc:identifier>',
    ).firstMatch(opfXml);
    metadata['identifier'] = idMatch?.group(1)?.trim();

    // Extract rights
    final rightsMatch = RegExp(
      r'<dc:rights[^>]*>([^<]+)</dc:rights>',
    ).firstMatch(opfXml);
    metadata['rights'] = rightsMatch?.group(1)?.trim();

    // Extract subjects
    final subjects = <String>[];
    final subjectMatches = RegExp(
      r'<dc:subject[^>]*>([^<]+)</dc:subject>',
    ).allMatches(opfXml);
    for (final match in subjectMatches) {
      final subject = match.group(1)?.trim();
      if (subject != null) subjects.add(subject);
    }
    metadata['subjects'] = subjects;

    // Extract version
    final versionMatch = RegExp(r'version="([^"]+)"').firstMatch(opfXml);
    metadata['version'] = versionMatch?.group(1);
  } catch (e) {
    debugPrint('Error parsing OPF metadata: $e');
  }

  return metadata;
}

/// Parse OPF manifest
Map<String, Map<String, String>> _parseOpfManifest(
  String opfXml,
  String basePath,
) {
  final manifest = <String, Map<String, String>>{};

  try {
    final manifestMatch = RegExp(
      r'<manifest[^>]*>([\s\S]*?)</manifest>',
    ).firstMatch(opfXml);
    if (manifestMatch != null) {
      final manifestContent = manifestMatch.group(1)!;
      final itemMatches = RegExp(
        r'<item\s+([^>]+)/>|<item\s+([^>]+)>\s*</item>',
      ).allMatches(manifestContent);

      for (final match in itemMatches) {
        final attrs = match.group(1) ?? match.group(2) ?? '';

        final id = RegExp(r'id="([^"]+)"').firstMatch(attrs)?.group(1);
        final href = RegExp(r'href="([^"]+)"').firstMatch(attrs)?.group(1);
        final mediaType = RegExp(
          r'media-type="([^"]+)"',
        ).firstMatch(attrs)?.group(1);
        final properties = RegExp(
          r'properties="([^"]+)"',
        ).firstMatch(attrs)?.group(1);

        if (id != null && href != null) {
          manifest[id] = {
            'id': id,
            'href': path.normalize(path.join(basePath, href)),
            'media-type': mediaType ?? '',
            'properties': properties ?? '',
          };
        }
      }
    }
  } catch (e) {
    debugPrint('Error parsing OPF manifest: $e');
  }

  return manifest;
}

/// Parse OPF spine
List<Map<String, String>> _parseOpfSpine(
  String opfXml,
  Map<String, Map<String, String>> manifest,
) {
  final spine = <Map<String, String>>[];

  try {
    final spineMatch = RegExp(
      r'<spine[^>]*>([\s\S]*?)</spine>',
    ).firstMatch(opfXml);
    if (spineMatch != null) {
      final spineContent = spineMatch.group(1)!;
      final itemRefMatches = RegExp(
        r'<itemref\s+([^>]+)/?>',
      ).allMatches(spineContent);

      for (final match in itemRefMatches) {
        final attrs = match.group(1)!;
        final idref = RegExp(r'idref="([^"]+)"').firstMatch(attrs)?.group(1);

        if (idref != null && manifest.containsKey(idref)) {
          spine.add(manifest[idref]!);
        }
      }
    }
  } catch (e) {
    debugPrint('Error parsing OPF spine: $e');
  }

  return spine;
}

/// Find cover image path
String? _findCoverPath(
  String opfXml,
  Map<String, Map<String, String>> manifest,
  String basePath,
) {
  try {
    // Method 1: Look for meta cover element
    final coverMetaMatch = RegExp(
      r'<meta\s+name="cover"\s+content="([^"]+)"',
    ).firstMatch(opfXml);
    if (coverMetaMatch != null) {
      final coverId = coverMetaMatch.group(1);
      if (coverId != null && manifest.containsKey(coverId)) {
        return manifest[coverId]!['href'];
      }
    }

    // Method 2: Look for item with cover-image properties
    for (final item in manifest.values) {
      if (item['properties']?.contains('cover-image') == true) {
        return item['href'];
      }
    }

    // Method 3: Look for item with id containing 'cover'
    for (final item in manifest.values) {
      if (item['id']?.toLowerCase().contains('cover') == true &&
          item['media-type']?.startsWith('image/') == true) {
        return item['href'];
      }
    }
  } catch (e) {
    debugPrint('Error finding cover: $e');
  }

  return null;
}

/// Parse NCX navigation document
List<TocEntry> _parseNcx(String ncxXml, String basePath) {
  final toc = <TocEntry>[];

  try {
    final navMapMatch = RegExp(
      r'<navMap[^>]*>([\s\S]*?)</navMap>',
    ).firstMatch(ncxXml);
    if (navMapMatch != null) {
      final navMapContent = navMapMatch.group(1)!;
      final navPoints = _parseNavPoints(navMapContent, basePath, 0);
      toc.addAll(navPoints);
    }
  } catch (e) {
    debugPrint('Error parsing NCX: $e');
  }

  return toc;
}

/// Parse nav points recursively
List<TocEntry> _parseNavPoints(String content, String basePath, int level) {
  final entries = <TocEntry>[];

  try {
    final navPointPattern = RegExp(
      r'<navPoint[^>]*>([\s\S]*?)</navPoint>',
      multiLine: true,
    );

    int playOrder = 0;
    for (final match in navPointPattern.allMatches(content)) {
      final navPointContent = match.group(1)!;

      // Extract label
      final labelMatch = RegExp(
        r'<text>([^<]+)</text>',
      ).firstMatch(navPointContent);
      final label = labelMatch?.group(1)?.trim() ?? '';

      // Extract content src
      final srcMatch = RegExp(
        r'<content\s+src="([^"]+)"',
      ).firstMatch(navPointContent);
      final src = srcMatch?.group(1) ?? '';

      // Parse href and anchor
      String href;
      String? anchor;
      if (src.contains('#')) {
        final parts = src.split('#');
        href = path.normalize(path.join(basePath, parts[0]));
        anchor = parts.length > 1 ? parts[1] : null;
      } else {
        href = path.normalize(path.join(basePath, src));
      }

      // Find nested nav points
      final children = _parseNavPoints(navPointContent, basePath, level + 1);

      entries.add(
        TocEntry(
          title: label,
          href: href,
          level: level,
          children: children,
          anchor: anchor,
          playOrder: playOrder++,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error parsing nav points: $e');
  }

  return entries;
}

/// Extract chapter content (runs in isolate)
EpubChapter _extractChapterContent(_ExtractChapterParams params) {
  try {
    final archive = ZipDecoder().decodeBytes(params.bytes);

    // Find chapter file
    final chapterFile = archive.findFile(params.chapterHref);
    if (chapterFile == null) {
      throw EpubParseException.missingComponent(component: params.chapterHref);
    }

    final htmlContent = utf8.decode(chapterFile.content as List<int>);

    // Parse HTML
    final document = html_parser.parse(htmlContent);
    final body = document.body;

    // Extract text
    final textContent = body?.text ?? '';

    // Extract title
    String title = 'Chapter ${params.chapterIndex + 1}';
    final headings = body?.querySelectorAll('h1, h2, h3');
    if (headings != null && headings.isNotEmpty) {
      title = headings.first.text.trim();
      if (title.isEmpty) {
        title = 'Chapter ${params.chapterIndex + 1}';
      }
    }

    // Count words
    final wordCount = textContent
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    // FIXED: Extract images
    final images = _extractImagesInIsolate(document, params.chapterHref);

    // FIXED: Extract links
    final links = _extractLinksInIsolate(document);

    return EpubChapter(
      id: 'chapter_${params.bookId}_${params.chapterIndex}',
      title: title,
      index: params.chapterIndex,
      htmlContent: htmlContent,
      textContent: textContent,
      href: params.chapterHref,
      mediaType: 'application/xhtml+xml',
      wordCount: wordCount,
      characterCount: textContent.length,
      estimatedReadingMinutes: (wordCount / 200).ceil(),
      images: images, // Now populated!
      links: links, // Now populated!
      isLoaded: true,
      bookId: params.bookId,
    );
  } catch (e) {
    if (e is EpubException) rethrow;
    throw EpubParseException.invalidFormat(originalError: e);
  }
}

/// Extract images from document (isolate-safe, no debugPrint)
List<ChapterImage> _extractImagesInIsolate(
  html_dom.Document document,
  String chapterHref,
) {
  final images = <ChapterImage>[];
  final basePath = path.dirname(chapterHref);

  try {
    // Extract img elements
    final imgElements = document.querySelectorAll('img');
    for (int i = 0; i < imgElements.length; i++) {
      final img = imgElements[i];
      final src = img.attributes['src'];
      if (src != null && src.isNotEmpty) {
        final resolvedSrc = _resolvePathInIsolate(src, basePath);
        images.add(
          ChapterImage(
            id: 'img_${i}_${src.hashCode}',
            src: resolvedSrc,
            alt: img.attributes['alt'],
            title: img.attributes['title'],
          ),
        );
      }
    }

    // Extract SVG images
    final svgElements = document.querySelectorAll('svg image');
    for (int i = 0; i < svgElements.length; i++) {
      final svg = svgElements[i];
      final href = svg.attributes['xlink:href'] ?? svg.attributes['href'];
      if (href != null && href.isNotEmpty) {
        final resolvedSrc = _resolvePathInIsolate(href, basePath);
        images.add(
          ChapterImage(id: 'svg_img_${i}_${href.hashCode}', src: resolvedSrc),
        );
      }
    }

    // Also check for image elements inside object/embed tags
    final objectElements = document.querySelectorAll(
      'object[type^="image"], embed[type^="image"]',
    );
    for (int i = 0; i < objectElements.length; i++) {
      final obj = objectElements[i];
      final data = obj.attributes['data'] ?? obj.attributes['src'];
      if (data != null && data.isNotEmpty) {
        final resolvedSrc = _resolvePathInIsolate(data, basePath);
        images.add(
          ChapterImage(id: 'obj_img_${i}_${data.hashCode}', src: resolvedSrc),
        );
      }
    }
  } catch (_) {
    // Silently fail in isolate
  }

  return images;
}

/// Extract links from document (isolate-safe)
List<ChapterLink> _extractLinksInIsolate(html_dom.Document document) {
  final links = <ChapterLink>[];

  try {
    final anchorElements = document.querySelectorAll('a');
    for (final anchor in anchorElements) {
      final href = anchor.attributes['href'];
      if (href != null && href.isNotEmpty) {
        LinkType type;
        String? targetChapterId;
        String? anchorId;

        if (href.startsWith('http://') || href.startsWith('https://')) {
          type = LinkType.external;
        } else if (href.startsWith('#')) {
          type = LinkType.internal;
          anchorId = href.substring(1);
        } else if (href.contains('#')) {
          type = LinkType.internal;
          final parts = href.split('#');
          targetChapterId = parts[0];
          anchorId = parts.length > 1 ? parts[1] : null;
        } else {
          type = LinkType.internal;
          targetChapterId = href;
        }

        if (href.contains('note') ||
            href.contains('footnote') ||
            href.contains('fn')) {
          type = LinkType.footnote;
        }

        links.add(
          ChapterLink(
            href: href,
            text: anchor.text.trim(),
            type: type,
            targetChapterId: targetChapterId,
            anchor: anchorId,
          ),
        );
      }
    }
  } catch (_) {
    // Silently fail in isolate
  }

  return links;
}

/// Resolve path relative to base (isolate-safe)
String _resolvePathInIsolate(String src, String basePath) {
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return src;
  }
  if (src.startsWith('/')) {
    return src.substring(1);
  }
  return path.normalize(path.join(basePath, src));
}

/// Extract cover image (runs in isolate)
Uint8List? _extractCoverImage(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) return null;

    final containerXml = utf8.decode(containerFile.content as List<int>);
    final opfPath = _extractOpfPath(containerXml);
    if (opfPath == null) return null;

    // Find OPF
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) return null;

    final opfXml = utf8.decode(opfFile.content as List<int>);
    final basePath = path.dirname(opfPath);

    // Parse manifest
    final manifest = _parseOpfManifest(opfXml, basePath);

    // Find cover path
    final coverPath = _findCoverPath(opfXml, manifest, basePath);
    if (coverPath == null) return null;

    // Extract cover image
    final coverFile = archive.findFile(coverPath);
    if (coverFile == null) return null;

    return Uint8List.fromList(coverFile.content as List<int>);
  } catch (e) {
    debugPrint('Error extracting cover: $e');
    return null;
  }
}

/// Extract images from chapter (runs in isolate)
Map<String, Uint8List> _extractImagesFromChapter(_ExtractImagesParams params) {
  final images = <String, Uint8List>{};

  try {
    final archive = ZipDecoder().decodeBytes(params.bytes);

    // Find chapter file
    final chapterFile = archive.findFile(params.chapterHref);
    if (chapterFile == null) return images;

    final htmlContent = utf8.decode(chapterFile.content as List<int>);
    final document = html_parser.parse(htmlContent);
    final basePath = path.dirname(params.chapterHref);

    // Find all images
    final imgElements = document.querySelectorAll('img');
    for (final img in imgElements) {
      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;

      // IMPORTANT: resolve path exactly like _extractImagesFromDocument
      final resolvedPath = src.startsWith('/')
          ? src.substring(1)
          : path.normalize(path.join(basePath, src));

      final imageFile = archive.findFile(resolvedPath);
      if (imageFile != null) {
        images[resolvedPath] = Uint8List.fromList(
          imageFile.content as List<int>,
        );
      }
    }
  } catch (e) {
    debugPrint('Error extracting chapter images: $e');
  }

  return images;
}

/// Extract table of contents (runs in isolate)
List<TocEntry> _extractTableOfContents(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) return [];

    final containerXml = utf8.decode(containerFile.content as List<int>);
    final opfPath = _extractOpfPath(containerXml);
    if (opfPath == null) return [];

    // Find OPF
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) return [];

    final opfXml = utf8.decode(opfFile.content as List<int>);
    final basePath = path.dirname(opfPath);

    // Parse manifest to find NCX
    final manifest = _parseOpfManifest(opfXml, basePath);
    final ncxPath = manifest['ncx']?['href'];

    if (ncxPath != null) {
      final ncxFile = archive.findFile(ncxPath);
      if (ncxFile != null) {
        final ncxXml = utf8.decode(ncxFile.content as List<int>);
        return _parseNcx(ncxXml, path.dirname(ncxPath));
      }
    }
  } catch (e) {
    debugPrint('Error extracting TOC: $e');
  }

  return [];
}

/// Search in EPUB (runs in isolate)
List<SearchResult> _searchInEpub(_SearchParams params) {
  final results = <SearchResult>[];

  try {
    final archive = ZipDecoder().decodeBytes(params.bytes);

    // Find container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) return results;

    final containerXml = utf8.decode(containerFile.content as List<int>);
    final opfPath = _extractOpfPath(containerXml);
    if (opfPath == null) return results;

    // Find OPF
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) return results;

    final opfXml = utf8.decode(opfFile.content as List<int>);
    final basePath = path.dirname(opfPath);

    // Parse manifest and spine
    final manifest = _parseOpfManifest(opfXml, basePath);
    final spine = _parseOpfSpine(opfXml, manifest);

    final query = params.caseSensitive
        ? params.query
        : params.query.toLowerCase();

    // Search in each chapter
    for (
      int i = 0;
      i < spine.length && results.length < params.maxResults;
      i++
    ) {
      final item = spine[i];
      final href = item['href'];
      if (href == null) continue;

      final chapterFile = archive.findFile(href);
      if (chapterFile == null) continue;

      final htmlContent = utf8.decode(chapterFile.content as List<int>);
      final document = html_parser.parse(htmlContent);
      final textContent = document.body?.text ?? '';

      final searchText = params.caseSensitive
          ? textContent
          : textContent.toLowerCase();

      int offset = 0;
      while (offset < searchText.length && results.length < params.maxResults) {
        final index = searchText.indexOf(query, offset);
        if (index == -1) break;

        // Get context
        final contextStart = (index - 50).clamp(0, textContent.length);
        final contextEnd = (index + query.length + 50).clamp(
          0,
          textContent.length,
        );
        final context = textContent.substring(contextStart, contextEnd);

        results.add(
          SearchResult(
            chapterIndex: i,
            chapterHref: href,
            text: textContent.substring(
              index,
              (index + query.length).clamp(0, textContent.length),
            ),
            context: context,
            offset: index,
          ),
        );

        offset = index + 1;
      }
    }
  } catch (e) {
    debugPrint('Error searching in EPUB: $e');
  }

  return results;
}

/// Validate EPUB file (runs in isolate)
EpubValidationResult _validateEpubFile(Uint8List bytes) {
  final errors = <String>[];
  final warnings = <String>[];
  bool isValid = true;

  try {
    // Try to decode as ZIP
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return EpubValidationResult(
        isValid: false,
        errors: ['Invalid ZIP archive: $e'],
        warnings: [],
      );
    }

    // Check for mimetype
    final mimetypeFile = archive.findFile('mimetype');
    if (mimetypeFile == null) {
      warnings.add('Missing mimetype file');
    } else {
      final mimetype = utf8.decode(mimetypeFile.content as List<int>).trim();
      if (mimetype != 'application/epub+zip') {
        warnings.add('Invalid mimetype: $mimetype');
      }
    }

    // Check for container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      errors.add('Missing META-INF/container.xml');
      isValid = false;
    } else {
      final containerXml = utf8.decode(containerFile.content as List<int>);
      final opfPath = _extractOpfPath(containerXml);

      if (opfPath == null) {
        errors.add('Cannot find OPF file path in container.xml');
        isValid = false;
      } else {
        // Check for OPF file
        final opfFile = archive.findFile(opfPath);
        if (opfFile == null) {
          errors.add('Missing OPF file: $opfPath');
          isValid = false;
        } else {
          final opfXml = utf8.decode(opfFile.content as List<int>);

          // Check for required metadata
          if (!opfXml.contains('<dc:title')) {
            warnings.add('Missing title in metadata');
          }

          // Check for spine
          if (!opfXml.contains('<spine')) {
            errors.add('Missing spine element');
            isValid = false;
          }

          // Check for manifest
          if (!opfXml.contains('<manifest')) {
            errors.add('Missing manifest element');
            isValid = false;
          }
        }
      }
    }
  } catch (e) {
    errors.add('Validation error: $e');
    isValid = false;
  }

  return EpubValidationResult(
    isValid: isValid,
    errors: errors,
    warnings: warnings,
  );
}

// =============================================================================
// HELPER CLASSES
// =============================================================================

/// Search result
class SearchResult {
  final int chapterIndex;
  final String chapterHref;
  final String text;
  final String context;
  final int offset;

  const SearchResult({
    required this.chapterIndex,
    required this.chapterHref,
    required this.text,
    required this.context,
    required this.offset,
  });

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'chapterHref': chapterHref,
    'text': text,
    'context': context,
    'offset': offset,
  };
}

/// EPUB validation result
class EpubValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const EpubValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'errors': errors,
    'warnings': warnings,
  };
}

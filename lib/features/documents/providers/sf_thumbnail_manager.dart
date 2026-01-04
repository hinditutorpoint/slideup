import 'dart:async';
import 'dart:typed_data';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

class RgbaThumb {
  final Uint8List pixels; // RGBA8888 pixels
  final int width;
  final int height;

  const RgbaThumb({
    required this.pixels,
    required this.width,
    required this.height,
  });
}

class SfThumbnailManager {
  String? _docId;
  Uint8List? _bytes;

  List<double>? _pagesW; // index same as Syncfusion platform (often 1-based)
  List<double>? _pagesH;

  final Map<int, RgbaThumb> _cache = <int, RgbaThumb>{};

  Future<void> _queue = Future.value(); // serialize heavy rendering work

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;

  Future<void> open({required Uint8List bytes, required String documentId}) {
    return _enqueue(() async {
      if (_docId == documentId && _bytes != null) return;

      await close();

      _docId = documentId;
      _bytes = bytes;

      await PdfViewerPlatform.instance.initializePdfRenderer(bytes, documentId);

      final w = await PdfViewerPlatform.instance.getPagesWidth(documentId);
      final h = await PdfViewerPlatform.instance.getPagesHeight(documentId);

      _pagesW = w?.map(_toDouble).toList();
      _pagesH = h?.map(_toDouble).toList();

      _cache.clear();
    });
  }

  Future<RgbaThumb?> getThumb({
    required int pageNumber, // 1-based
    int thumbWidth = 200,
  }) {
    return _enqueue(() async {
      final docId = _docId;
      if (docId == null || _pagesW == null || _pagesH == null) return null;

      final cached = _cache[pageNumber];
      if (cached != null) return cached;

      // Syncfusion arrays are typically 1-based; guard anyway.
      final pw = (pageNumber < _pagesW!.length) ? _pagesW![pageNumber] : 0.0;
      final ph = (pageNumber < _pagesH!.length) ? _pagesH![pageNumber] : 0.0;
      if (pw <= 0 || ph <= 0) return null;

      final ratio = pw / ph;
      final thumbHeight = (thumbWidth / ratio).round().clamp(1, 4000);

      final pixels = await PdfViewerPlatform.instance.getPage(
        pageNumber,
        thumbWidth,
        thumbHeight,
        docId,
      );

      if (pixels == null) return null;

      final t = RgbaThumb(
        pixels: pixels,
        width: thumbWidth,
        height: thumbHeight,
      );
      _cache[pageNumber] = t;

      // small eviction
      if (_cache.length > 120) {
        _cache.remove(_cache.keys.first);
      }
      return t;
    });
  }

  Future<void> close() {
    return _enqueue(() async {
      final docId = _docId;
      if (docId != null) {
        try {
          await PdfViewerPlatform.instance.closeDocument(docId);
        } catch (_) {}
      }
      _docId = null;
      _bytes = null;
      _pagesW = null;
      _pagesH = null;
      _cache.clear();
    });
  }
}

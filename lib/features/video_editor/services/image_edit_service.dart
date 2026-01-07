import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/video_edit_settings.dart';
import 'package:slideup/core/utils/safe_async.dart';
import 'package:slideup/core/utils/isolate_helper.dart';

// ═══════════════════════════════════════════════════════
// ✅ IMAGE EDIT MODELS
// ═══════════════════════════════════════════════════════

@immutable
class ImageSize {
  final int width;
  final int height;

  const ImageSize({required this.width, required this.height});

  double get aspectRatio => width / height;

  ImageSize copyWith({int? width, int? height}) {
    return ImageSize(width: width ?? this.width, height: height ?? this.height);
  }

  // Preset sizes
  static const ImageSize hd720 = ImageSize(width: 1280, height: 720);
  static const ImageSize fhd1080 = ImageSize(width: 1920, height: 1080);
  static const ImageSize uhd4k = ImageSize(width: 3840, height: 2160);
  static const ImageSize square1080 = ImageSize(width: 1080, height: 1080);
  static const ImageSize instagram = ImageSize(width: 1080, height: 1350);
  static const ImageSize story = ImageSize(width: 1080, height: 1920);

  static List<ImageSize> get presets => [
    hd720,
    fhd1080,
    uhd4k,
    square1080,
    instagram,
    story,
  ];
}

@immutable
class CropRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory CropRect.fromRect(
    int imageWidth,
    int imageHeight,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return CropRect(
      x: (left * imageWidth).clamp(0, imageWidth.toDouble()),
      y: (top * imageHeight).clamp(0, imageHeight.toDouble()),
      width: ((right - left) * imageWidth).clamp(1, imageWidth.toDouble()),
      height: ((bottom - top) * imageHeight).clamp(1, imageHeight.toDouble()),
    );
  }
}

enum ImageShape { rectangle, circle, triangle, star, heart, arrow }

@immutable
class ShapeConfig {
  final ImageShape shape;
  final int color;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool filled;
  final double strokeWidth;

  const ShapeConfig({
    required this.shape,
    required this.color,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.filled = true,
    this.strokeWidth = 2.0,
  });
}

@immutable
class TextConfig {
  final String text;
  final String fontFamily;
  final double fontSize;
  final int color;
  final int backgroundColor;
  final bool bold;
  final bool italic;
  final double x;
  final double y;

  const TextConfig({
    required this.text,
    this.fontFamily = 'Arial',
    this.fontSize = 48,
    this.color = 0xFFFFFFFF,
    this.backgroundColor = 0x00000000,
    this.bold = false,
    this.italic = false,
    required this.x,
    required this.y,
  });
}

// ═══════════════════════════════════════════════════════
// ✅ IMAGE EDIT ERROR
// ═══════════════════════════════════════════════════════

enum ImageEditErrorType {
  fileNotFound,
  invalidInput,
  processingFailed,
  cancelled,
  timeout,
  unsupportedFormat,
  unknown,
}

class ImageEditError implements Exception {
  final ImageEditErrorType type;
  final String message;
  final String? details;
  final Object? originalError;

  const ImageEditError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() =>
      'ImageEditError($type): $message${details != null ? ' - $details' : ''}';

  factory ImageEditError.fileNotFound(String path) => ImageEditError(
    type: ImageEditErrorType.fileNotFound,
    message: 'Image file not found',
    details: path,
  );

  factory ImageEditError.invalidInput(String reason) => ImageEditError(
    type: ImageEditErrorType.invalidInput,
    message: 'Invalid input',
    details: reason,
  );

  factory ImageEditError.processingFailed(String operation, [Object? error]) =>
      ImageEditError(
        type: ImageEditErrorType.processingFailed,
        message: 'Image processing failed',
        details: operation,
        originalError: error,
      );

  factory ImageEditError.cancelled() => const ImageEditError(
    type: ImageEditErrorType.cancelled,
    message: 'Operation cancelled',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ IMAGE EDIT SERVICE
// ═══════════════════════════════════════════════════════

class ImageEditService {
  static final ImageEditService _instance = ImageEditService._internal();
  factory ImageEditService() => _instance;
  ImageEditService._internal();

  static const Duration _defaultTimeout = Duration(minutes: 5);

  final _uuid = const Uuid();
  bool _isProcessing = false;
  bool _isCancelled = false;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;
  bool get isProcessing => _isProcessing;
  bool get isCancelled => _isCancelled;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    return SafeAsync.run(() async {
      debugPrint('✅ ImageEditService initialized');
    }, operationName: 'ImageEditService.initialize');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL OPERATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> cancelCurrentOperation() async {
    return SafeAsync.run(() async {
      _isCancelled = true;
      _isProcessing = false;
      debugPrint('✅ Image operation cancelled');
    }, operationName: 'ImageEditService.cancel');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CROP IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> cropImage({
    required String inputPath,
    required CropRect cropRect,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        // Load and decode in isolate
        final imageBytes = await File(inputPath).readAsBytes();

        final cropResult = await IsolateHelper.instance.compute(
          _cropImageIsolate,
          _CropParams(
            imageBytes: imageBytes,
            x: cropRect.x.toInt(),
            y: cropRect.y.toInt(),
            width: cropRect.width.toInt(),
            height: cropRect.height.toInt(),
          ),
        );

        if (cropResult.isFailure) {
          throw cropResult.error!;
        }

        onProgress?.call(0.8);

        final croppedBytes = cropResult.requireData;
        final outputResult = await _getOutputPath('cropped_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(croppedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Image cropped: $output');
        return output;
      },
      operationName: 'cropImage',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RESIZE IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> resizeImage({
    required String inputPath,
    required ImageSize size,
    bool maintainAspectRatio = true,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final resizeResult = await IsolateHelper.instance.compute(
          _resizeImageIsolate,
          _ResizeParams(
            imageBytes: imageBytes,
            width: size.width,
            height: size.height,
            maintainAspectRatio: maintainAspectRatio,
          ),
        );

        if (resizeResult.isFailure) {
          throw resizeResult.error!;
        }

        onProgress?.call(0.8);

        final resizedBytes = resizeResult.requireData;
        final outputResult = await _getOutputPath('resized_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(resizedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Image resized: $output');
        return output;
      },
      operationName: 'resizeImage',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ APPLY COLOR GRADING
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyColorGrading({
    required String inputPath,
    required ColorGradeSettings settings,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (settings.isDefault) {
      return Result.success(inputPath);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final gradeResult = await IsolateHelper.instance.compute(
          _applyColorGradeIsolate,
          _ColorGradeParams(imageBytes: imageBytes, settings: settings),
        );

        if (gradeResult.isFailure) {
          throw gradeResult.error!;
        }

        onProgress?.call(0.8);

        final gradedBytes = gradeResult.requireData;
        final outputResult = await _getOutputPath('graded_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(gradedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Color grading applied: $output');
        return output;
      },
      operationName: 'applyColorGrading',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADD TEXT TO IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> addText({
    required String inputPath,
    required TextConfig config,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final textResult = await IsolateHelper.instance.compute(
          _addTextIsolate,
          _TextParams(imageBytes: imageBytes, config: config),
        );

        if (textResult.isFailure) {
          throw textResult.error!;
        }

        onProgress?.call(0.8);

        final processedBytes = textResult.requireData;
        final outputResult = await _getOutputPath('text_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(processedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Text added: $output');
        return output;
      },
      operationName: 'addText',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADD SHAPE TO IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> addShape({
    required String inputPath,
    required ShapeConfig config,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final shapeResult = await IsolateHelper.instance.compute(
          _addShapeIsolate,
          _ShapeParams(imageBytes: imageBytes, config: config),
        );

        if (shapeResult.isFailure) {
          throw shapeResult.error!;
        }

        onProgress?.call(0.8);

        final processedBytes = shapeResult.requireData;
        final outputResult = await _getOutputPath('shape_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(processedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Shape added: $output');
        return output;
      },
      operationName: 'addShape',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ AUTO ENHANCE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> autoEnhance({
    required String inputPath,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final enhanceResult = await IsolateHelper.instance.compute(
          _autoEnhanceIsolate,
          imageBytes,
        );

        if (enhanceResult.isFailure) {
          throw enhanceResult.error!;
        }

        onProgress?.call(0.8);

        final enhancedBytes = enhanceResult.requireData;
        final outputResult = await _getOutputPath('enhanced_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(enhancedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Image auto-enhanced: $output');
        return output;
      },
      operationName: 'autoEnhance',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ REMOVE BACKGROUND (Simple edge detection based)
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> removeBackground({
    required String inputPath,
    int tolerance = 30,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final bgRemoveResult = await IsolateHelper.instance.compute(
          _removeBackgroundIsolate,
          _BackgroundRemovalParams(
            imageBytes: imageBytes,
            tolerance: tolerance,
          ),
        );

        if (bgRemoveResult.isFailure) {
          throw bgRemoveResult.error!;
        }

        onProgress?.call(0.8);

        final processedBytes = bgRemoveResult.requireData;
        final outputResult = await _getOutputPath('no_bg_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(processedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Background removed: $output');
        return output;
      },
      operationName: 'removeBackground',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ROTATE IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> rotateImage({
    required String inputPath,
    required double angle,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final rotateResult = await IsolateHelper.instance.compute(
          _rotateImageIsolate,
          _RotateParams(imageBytes: imageBytes, angle: angle),
        );

        if (rotateResult.isFailure) {
          throw rotateResult.error!;
        }

        onProgress?.call(0.8);

        final rotatedBytes = rotateResult.requireData;
        final outputResult = await _getOutputPath('rotated_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(rotatedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Image rotated: $output');
        return output;
      },
      operationName: 'rotateImage',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FLIP IMAGE
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> flipImage({
    required String inputPath,
    bool horizontal = true,
    bool vertical = false,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        ImageEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        onProgress?.call(0.1);

        final imageBytes = await File(inputPath).readAsBytes();

        final flipResult = await IsolateHelper.instance.compute(
          _flipImageIsolate,
          _FlipParams(
            imageBytes: imageBytes,
            horizontal: horizontal,
            vertical: vertical,
          ),
        );

        if (flipResult.isFailure) {
          throw flipResult.error!;
        }

        onProgress?.call(0.8);

        final flippedBytes = flipResult.requireData;
        final outputResult = await _getOutputPath('flipped_image', 'png');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        await File(output).writeAsBytes(flippedBytes);

        onProgress?.call(1.0);
        debugPrint('✅ Image flipped: $output');
        return output;
      },
      operationName: 'flipImage',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> _validateInputFile(String path) async {
    return SafeAsync.run(() async {
      final file = File(path);
      if (!await file.exists()) {
        throw ImageEditError.fileNotFound(path);
      }
      final stat = await file.stat();
      if (stat.size == 0) {
        throw ImageEditError.invalidInput('File is empty');
      }
    }, operationName: '_validateInputFile');
  }

  Future<Result<String>> _getOutputPath(String prefix, String ext) async {
    return SafeAsync.run(() async {
      final outputDir = await getExternalStorageDirectory();
      if (outputDir == null) {
        throw ImageEditError.processingFailed('Cannot access storage');
      }

      final imageDir = Directory(p.join(outputDir.path, 'processed_images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      return p.join(imageDir.path, '${prefix}_${_uuid.v4()}.$ext');
    }, operationName: '_getOutputPath');
  }

  void _startProcessing() {
    _isProcessing = true;
    _isCancelled = false;
  }

  void _stopProcessing() {
    _isProcessing = false;
  }

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ ISOLATE PARAMETER CLASSES
// ═══════════════════════════════════════════════════════

class _CropParams {
  final Uint8List imageBytes;
  final int x;
  final int y;
  final int width;
  final int height;

  _CropParams({
    required this.imageBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class _ResizeParams {
  final Uint8List imageBytes;
  final int width;
  final int height;
  final bool maintainAspectRatio;

  _ResizeParams({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.maintainAspectRatio,
  });
}

class _ColorGradeParams {
  final Uint8List imageBytes;
  final ColorGradeSettings settings;

  _ColorGradeParams({required this.imageBytes, required this.settings});
}

class _TextParams {
  final Uint8List imageBytes;
  final TextConfig config;

  _TextParams({required this.imageBytes, required this.config});
}

class _ShapeParams {
  final Uint8List imageBytes;
  final ShapeConfig config;

  _ShapeParams({required this.imageBytes, required this.config});
}

class _BackgroundRemovalParams {
  final Uint8List imageBytes;
  final int tolerance;

  _BackgroundRemovalParams({required this.imageBytes, required this.tolerance});
}

class _RotateParams {
  final Uint8List imageBytes;
  final double angle;

  _RotateParams({required this.imageBytes, required this.angle});
}

class _FlipParams {
  final Uint8List imageBytes;
  final bool horizontal;
  final bool vertical;

  _FlipParams({
    required this.imageBytes,
    required this.horizontal,
    required this.vertical,
  });
}

// ═══════════════════════════════════════════════════════
// ✅ ISOLATE FUNCTIONS (Top-level)
// ═══════════════════════════════════════════════════════

Uint8List _cropImageIsolate(_CropParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  final cropped = img.copyCrop(
    image,
    x: params.x,
    y: params.y,
    width: params.width,
    height: params.height,
  );

  return Uint8List.fromList(img.encodePng(cropped));
}

Uint8List _resizeImageIsolate(_ResizeParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  img.Image resized;

  if (params.maintainAspectRatio) {
    resized = img.copyResize(
      image,
      width: params.width,
      height: params.height,
      maintainAspect: true,
    );
  } else {
    resized = img.copyResize(image, width: params.width, height: params.height);
  }

  return Uint8List.fromList(img.encodePng(resized));
}

Uint8List _applyColorGradeIsolate(_ColorGradeParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  final s = params.settings;

  // Apply brightness
  var processed = img.adjustColor(
    image,
    brightness: s.brightness,
    contrast: s.contrast,
    saturation: s.saturation,
    hue: s.hue,
  );

  // Apply red/green/blue adjustments
  if (s.red != 1.0 || s.green != 1.0 || s.blue != 1.0) {
    for (final pixel in processed) {
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;

      pixel
        ..r = (r * s.red).clamp(0, 255).toInt()
        ..g = (g * s.green).clamp(0, 255).toInt()
        ..b = (b * s.blue).clamp(0, 255).toInt();
    }
  }

  return Uint8List.fromList(img.encodePng(processed));
}

Uint8List _addTextIsolate(_TextParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  final config = params.config;

  // Draw text using image package
  // Note: image package has limited font support, this is a basic implementation
  img.drawString(
    image,
    config.text,
    font: img.arial48,
    x: config.x.toInt(),
    y: config.y.toInt(),
    color: img.ColorRgba8(
      (config.color >> 16) & 0xFF,
      (config.color >> 8) & 0xFF,
      config.color & 0xFF,
      (config.color >> 24) & 0xFF,
    ),
  );

  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _addShapeIsolate(_ShapeParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  final config = params.config;
  final color = img.ColorRgba8(
    (config.color >> 16) & 0xFF,
    (config.color >> 8) & 0xFF,
    config.color & 0xFF,
    (config.color >> 24) & 0xFF,
  );

  final x = config.x.toInt();
  final y = config.y.toInt();
  final w = config.width.toInt();
  final h = config.height.toInt();

  switch (config.shape) {
    case ImageShape.rectangle:
      if (config.filled) {
        img.fillRect(image, x1: x, y1: y, x2: x + w, y2: y + h, color: color);
      } else {
        img.drawRect(image, x1: x, y1: y, x2: x + w, y2: y + h, color: color);
      }
      break;
    case ImageShape.circle:
      if (config.filled) {
        img.fillCircle(
          image,
          x: x + w ~/ 2,
          y: y + h ~/ 2,
          radius: w ~/ 2,
          color: color,
        );
      } else {
        img.drawCircle(
          image,
          x: x + w ~/ 2,
          y: y + h ~/ 2,
          radius: w ~/ 2,
          color: color,
        );
      }
      break;
    case ImageShape.triangle:
    case ImageShape.star:
    case ImageShape.heart:
    case ImageShape.arrow:
      img.fillRect(image, x1: x, y1: y, x2: x + w, y2: y + h, color: color);
      break;
  }

  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _autoEnhanceIsolate(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Auto enhance: normalize, increase contrast slightly, boost saturation slightly
  var enhanced = img.normalize(image, min: 0, max: 255);
  enhanced = img.adjustColor(enhanced, contrast: 1.1, saturation: 1.1);

  return Uint8List.fromList(img.encodePng(enhanced));
}

Uint8List _removeBackgroundIsolate(_BackgroundRemovalParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Simple background removal based on corner color
  // Get reference color from top-left corner
  final refPixel = image.getPixel(0, 0);
  final refR = refPixel.r.toInt();
  final refG = refPixel.g.toInt();
  final refB = refPixel.b.toInt();

  final tolerance = params.tolerance;

  // Make pixels similar to reference color transparent
  for (final pixel in image) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final diff = (r - refR).abs() + (g - refG).abs() + (b - refB).abs();

    if (diff < tolerance * 3) {
      pixel.a = 0;
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _rotateImageIsolate(_RotateParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  final rotated = img.copyRotate(image, angle: params.angle);

  return Uint8List.fromList(img.encodePng(rotated));
}

Uint8List _flipImageIsolate(_FlipParams params) {
  final image = img.decodeImage(params.imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  img.Image flipped = image;

  if (params.horizontal) {
    flipped = img.flipHorizontal(flipped);
  }

  if (params.vertical) {
    flipped = img.flipVertical(flipped);
  }

  return Uint8List.fromList(img.encodePng(flipped));
}

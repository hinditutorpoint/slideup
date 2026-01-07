import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/video_edit_settings.dart';

// ═══════════════════════════════════════════════════════
// ✅ AI PROVIDER CONFIGURATION
// ═══════════════════════════════════════════════════════

enum AiProvider {
  stabilityAi,
  openAi,
  replicate,
  deepAi,
  lexica,
  openRouter,
  cloudflare,
}

class AiProviderConfig {
  final AiProvider provider;
  final String apiKey;
  final String? baseUrl;
  final Map<String, String>? headers;

  const AiProviderConfig({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.headers,
  });

  static const Map<AiProvider, String> defaultBaseUrls = {
    AiProvider.stabilityAi: 'https://api.stability.ai/v1',
    AiProvider.openAi: 'https://api.openai.com/v1',
    AiProvider.replicate: 'https://api.replicate.com/v1',
    AiProvider.deepAi: 'https://api.deepai.org/api',
    AiProvider.lexica: 'https://lexica.art/api/v1',
    AiProvider.openRouter: 'https://api.openrouter.ai/v1',
    AiProvider.cloudflare: 'https://smplus.hinditutorpoint.workers.dev',
  };
}

// ═══════════════════════════════════════════════════════
// ✅ AI IMAGE SERVICE
// ═══════════════════════════════════════════════════════

class AiImageService {
  static final AiImageService _instance = AiImageService._internal();
  factory AiImageService() => _instance;
  AiImageService._internal();

  //final _uuid = const Uuid();
  final _httpClient = http.Client();

  // Configure your API keys here or load from secure storage
  AiProviderConfig? _config;

  // Cache for generated images
  final Map<String, AiGeneratedImage> _generatedImages = {};
  final List<AiGeneratedImage> _history = [];

  // Stream controllers
  final _generationController = StreamController<AiGenerationState>.broadcast();
  Stream<AiGenerationState> get generationStream =>
      _generationController.stream;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  // ═══════════════════════════════════════════════════════
  // ✅ CONFIGURATION
  // ═══════════════════════════════════════════════════════

  void configure(AiProviderConfig config) {
    _config = config;
    debugPrint('✅ AI Image Service configured with ${config.provider.name}');
  }

  bool get isConfigured => _config != null && _config!.apiKey.isNotEmpty;

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE IMAGE
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> generateImages(AiImageRequest request) async {
    if (!isConfigured) {
      throw Exception('AI service not configured. Call configure() first.');
    }

    if (_isGenerating) {
      throw Exception('Generation already in progress');
    }

    _isGenerating = true;
    _updateState(AiGenerationState.starting(request.prompt));

    try {
      List<AiGeneratedImage> images;

      switch (_config!.provider) {
        case AiProvider.stabilityAi:
          images = await _generateWithStabilityAi(request);
          break;
        case AiProvider.openAi:
          images = await _generateWithOpenAi(request);
          break;
        case AiProvider.replicate:
          images = await _generateWithReplicate(request);
          break;
        case AiProvider.deepAi:
          images = await _generateWithDeepAi(request);
          break;
        case AiProvider.lexica:
          images = await _searchLexica(request);
          break;
        case AiProvider.openRouter:
          images = await _generateWithOpenRouter(request);
          break;
        case AiProvider.cloudflare:
          images = await _generateWithCloudflare(request);
          break;
      }

      // Save to local storage
      final savedImages = <AiGeneratedImage>[];
      for (final image in images) {
        try {
          final saved = await _saveImageToLocal(image);
          savedImages.add(saved);
          _generatedImages[saved.id] = saved;
          _history.insert(0, saved);
        } catch (e) {
          debugPrint('❌ Save image error: $e');
          savedImages.add(image);
        }
      }

      _updateState(AiGenerationState.completed(savedImages));
      return savedImages;
    } catch (e) {
      debugPrint('❌ Generate images error: $e');
      _updateState(AiGenerationState.failed(e.toString()));
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OPEN ROUTER
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithOpenRouter(
    AiImageRequest request,
  ) async {
    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.openRouter]}/images/generations',
    );

    final dimensions = request.dimensions;
    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    final body = {
      'model': 'stabilityai/stable-diffusion-xl-base-1.0',
      'prompt': fullPrompt,
      'n': request.count,
      'size': '${dimensions['width']}x${dimensions['height']}',
    };

    _updateState(
      AiGenerationState.generating(0.3, 'Sending request to OpenRouter...'),
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_config!.apiKey}',
              'HTTP-Referer': 'https://your-app.com',
              'X-Title': 'Your App Name',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(minutes: 2));

      _updateState(AiGenerationState.generating(0.7, 'Processing response...'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageData = data['data'] as List;

        final images = <AiGeneratedImage>[];
        for (final item in imageData) {
          if (item['b64_json'] != null) {
            final bytes = base64Decode(item['b64_json']);
            images.add(
              AiGeneratedImage.create(
                prompt: request.prompt,
                bytes: bytes,
                width: dimensions['width']!,
                height: dimensions['height']!,
              ),
            );
          } else if (item['url'] != null) {
            final imageBytes = await _downloadImage(item['url']);
            if (imageBytes != null) {
              images.add(
                AiGeneratedImage.create(
                  prompt: request.prompt,
                  url: item['url'],
                  bytes: imageBytes,
                  width: dimensions['width']!,
                  height: dimensions['height']!,
                ),
              );
            }
          }
        }
        return images;
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'OpenRouter error: ${error['error']?['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLOUDFLARE WORKERS AI
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithCloudflare(
    AiImageRequest request,
  ) async {
    final baseUrl =
        _config!.baseUrl ??
        AiProviderConfig.defaultBaseUrls[AiProvider.cloudflare]!;
    final url = Uri.parse('$baseUrl/api/generate');

    final dimensions = request.dimensions;
    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    final body = {
      'prompt': fullPrompt,
      'negative_prompt': request.negativePrompt ?? 'blurry, bad quality',
      'width': dimensions['width'],
      'height': dimensions['height'],
      'num_steps': 20,
      'guidance': 7.5,
    };

    _updateState(
      AiGenerationState.generating(0.3, 'Generating with Cloudflare AI...'),
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (_config!.apiKey.isNotEmpty)
                'Authorization': 'Bearer ${_config!.apiKey}',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(minutes: 2));

      _updateState(AiGenerationState.generating(0.7, 'Processing...'));

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('image/')) {
          // Direct image response
          return [
            AiGeneratedImage.create(
              prompt: request.prompt,
              bytes: response.bodyBytes,
              width: dimensions['width']!,
              height: dimensions['height']!,
            ),
          ];
        } else {
          // JSON response with base64 or URL
          final data = json.decode(response.body);

          if (data['image'] != null) {
            final bytes = base64Decode(data['image']);
            return [
              AiGeneratedImage.create(
                prompt: request.prompt,
                bytes: bytes,
                width: dimensions['width']!,
                height: dimensions['height']!,
              ),
            ];
          } else if (data['url'] != null) {
            final imageBytes = await _downloadImage(data['url']);
            if (imageBytes != null) {
              return [
                AiGeneratedImage.create(
                  prompt: request.prompt,
                  url: data['url'],
                  bytes: imageBytes,
                  width: dimensions['width']!,
                  height: dimensions['height']!,
                ),
              ];
            }
          }

          throw Exception('Invalid response format from Cloudflare');
        }
      } else {
        throw Exception(
          'Cloudflare error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STABILITY AI
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithStabilityAi(
    AiImageRequest request,
  ) async {
    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.stabilityAi]}/generation/stable-diffusion-xl-1024-v1-0/text-to-image',
    );

    final dimensions = request.dimensions;
    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    final body = {
      'text_prompts': [
        {'text': fullPrompt, 'weight': 1.0},
        if (request.negativePrompt != null)
          {'text': request.negativePrompt, 'weight': -1.0},
      ],
      'cfg_scale': 7,
      'width': dimensions['width'],
      'height': dimensions['height'],
      'samples': request.count,
      'steps': 30,
    };

    _updateState(
      AiGenerationState.generating(0.3, 'Sending request to Stability AI...'),
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${_config!.apiKey}',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(minutes: 2));

      _updateState(AiGenerationState.generating(0.7, 'Processing response...'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artifacts = data['artifacts'] as List;

        final images = <AiGeneratedImage>[];
        for (final artifact in artifacts) {
          final base64Image = artifact['base64'] as String;
          final bytes = base64Decode(base64Image);

          images.add(
            AiGeneratedImage.create(
              prompt: request.prompt,
              bytes: bytes,
              width: dimensions['width']!,
              height: dimensions['height']!,
            ),
          );
        }

        return images;
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'Stability AI error: ${error['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OPENAI DALL-E
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithOpenAi(
    AiImageRequest request,
  ) async {
    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.openAi]}/images/generations',
    );

    final size = _getOpenAiSize(request.size);
    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    final body = {
      'model': 'dall-e-3',
      'prompt': fullPrompt,
      'n': request.count.clamp(1, 1), // DALL-E 3 only supports 1 at a time
      'size': size,
      'quality': 'standard',
      'response_format': 'b64_json',
    };

    _updateState(
      AiGenerationState.generating(0.3, 'Sending request to DALL-E...'),
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_config!.apiKey}',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(minutes: 2));

      _updateState(AiGenerationState.generating(0.7, 'Processing response...'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageData = data['data'] as List;

        final images = <AiGeneratedImage>[];
        final dimensions = request.dimensions;

        for (final item in imageData) {
          final base64Image = item['b64_json'] as String;
          final bytes = base64Decode(base64Image);

          images.add(
            AiGeneratedImage.create(
              prompt: request.prompt,
              bytes: bytes,
              width: dimensions['width']!,
              height: dimensions['height']!,
            ),
          );
        }

        return images;
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'OpenAI error: ${error['error']?['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      }
      rethrow;
    }
  }

  String _getOpenAiSize(AiImageSize size) {
    switch (size) {
      case AiImageSize.square:
        return '1024x1024';
      case AiImageSize.portrait:
        return '1024x1792';
      case AiImageSize.landscape:
      case AiImageSize.wide:
        return '1792x1024';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ REPLICATE (Stable Diffusion, Midjourney-style, etc.)
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithReplicate(
    AiImageRequest request,
  ) async {
    // Using SDXL model
    const modelVersion =
        'stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b';

    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.replicate]}/predictions',
    );

    final dimensions = request.dimensions;
    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    final body = {
      'version': modelVersion.split(':').last,
      'input': {
        'prompt': fullPrompt,
        'negative_prompt':
            request.negativePrompt ?? 'blurry, bad quality, distorted',
        'width': dimensions['width'],
        'height': dimensions['height'],
        'num_outputs': request.count,
        'num_inference_steps': 30,
        'guidance_scale': 7.5,
      },
    };

    _updateState(AiGenerationState.generating(0.2, 'Starting generation...'));

    try {
      // Create prediction
      final createResponse = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${_config!.apiKey}',
        },
        body: json.encode(body),
      );

      if (createResponse.statusCode != 201) {
        throw Exception('Replicate error: ${createResponse.body}');
      }

      final prediction = json.decode(createResponse.body);
      final predictionId = prediction['id'];
      final statusUrl = Uri.parse(
        '${AiProviderConfig.defaultBaseUrls[AiProvider.replicate]}/predictions/$predictionId',
      );

      // Poll for completion
      var progress = 0.3;
      while (true) {
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse = await _httpClient.get(
          statusUrl,
          headers: {'Authorization': 'Token ${_config!.apiKey}'},
        );

        final status = json.decode(statusResponse.body);
        final state = status['status'];

        progress = (progress + 0.1).clamp(0.3, 0.9);
        _updateState(
          AiGenerationState.generating(progress, 'Generating... ($state)'),
        );

        if (state == 'succeeded') {
          final outputs = status['output'] as List;
          final images = <AiGeneratedImage>[];

          for (final outputUrl in outputs) {
            final imageBytes = await _downloadImage(outputUrl);
            if (imageBytes != null) {
              images.add(
                AiGeneratedImage.create(
                  prompt: request.prompt,
                  url: outputUrl,
                  bytes: imageBytes,
                  width: dimensions['width']!,
                  height: dimensions['height']!,
                ),
              );
            }
          }

          return images;
        } else if (state == 'failed' || state == 'canceled') {
          throw Exception('Generation $state: ${status['error']}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DEEP AI
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _generateWithDeepAi(
    AiImageRequest request,
  ) async {
    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.deepAi]}/text2img',
    );

    final stylePrompt = _getStylePrompt(request.style);
    final fullPrompt = stylePrompt.isNotEmpty
        ? '${request.prompt}, $stylePrompt'
        : request.prompt;

    _updateState(
      AiGenerationState.generating(0.3, 'Generating with DeepAI...'),
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {'Api-Key': _config!.apiKey},
            body: {'text': fullPrompt, 'grid_size': '1'},
          )
          .timeout(const Duration(minutes: 2));

      _updateState(AiGenerationState.generating(0.7, 'Processing...'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['output_url'] as String;

        final imageBytes = await _downloadImage(imageUrl);
        if (imageBytes == null) {
          throw Exception('Failed to download generated image');
        }

        return [
          AiGeneratedImage.create(
            prompt: request.prompt,
            url: imageUrl,
            bytes: imageBytes,
            width: 512,
            height: 512,
          ),
        ];
      } else {
        throw Exception('DeepAI error: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LEXICA (Search existing AI art - Free)
  // ═══════════════════════════════════════════════════════

  Future<List<AiGeneratedImage>> _searchLexica(AiImageRequest request) async {
    final url = Uri.parse(
      '${AiProviderConfig.defaultBaseUrls[AiProvider.lexica]}/search?q=${Uri.encodeComponent(request.prompt)}',
    );

    _updateState(AiGenerationState.generating(0.5, 'Searching Lexica...'));

    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final images = data['images'] as List;

        final results = <AiGeneratedImage>[];
        final limit = request.count.clamp(1, 10);

        for (int i = 0; i < images.length && i < limit; i++) {
          final img = images[i];
          results.add(
            AiGeneratedImage.create(
              prompt: img['prompt'] ?? request.prompt,
              url: img['src'],
              width: img['width'] ?? 1024,
              height: img['height'] ?? 1024,
            ),
          );
        }

        return results;
      } else {
        throw Exception('Lexica error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STYLE PROMPTS
  // ═══════════════════════════════════════════════════════

  String _getStylePrompt(AiImageStyle style) {
    switch (style) {
      case AiImageStyle.realistic:
        return 'photorealistic, ultra detailed, 8k, professional photography';
      case AiImageStyle.artistic:
        return 'artistic, beautiful, creative, masterpiece';
      case AiImageStyle.anime:
        return 'anime style, manga, japanese animation, detailed';
      case AiImageStyle.cartoon:
        return 'cartoon style, colorful, fun, illustrated';
      case AiImageStyle.sketch:
        return 'pencil sketch, hand drawn, artistic sketch';
      case AiImageStyle.painting:
        return 'oil painting, canvas texture, artistic brush strokes';
      case AiImageStyle.threeD:
        return '3D render, CGI, octane render, unreal engine';
      case AiImageStyle.abstract:
        return 'abstract art, modern art, geometric shapes';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER METHODS
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('❌ Download image error: $e');
    }
    return null;
  }

  Future<AiGeneratedImage> _saveImageToLocal(AiGeneratedImage image) async {
    try {
      final dir = await _getAiImagesDirectory();
      final fileName = '${image.id}.png';
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);

      Uint8List? bytes = image.bytes;

      // Download if we only have URL
      if (bytes == null && image.url != null) {
        bytes = await _downloadImage(image.url!);
      }

      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return AiGeneratedImage(
          id: image.id,
          prompt: image.prompt,
          localPath: filePath,
          url: image.url,
          bytes: bytes,
          width: image.width,
          height: image.height,
          createdAt: image.createdAt,
        );
      }

      return image;
    } catch (e) {
      debugPrint('❌ Save to local error: $e');
      return image;
    }
  }

  Future<Directory> _getAiImagesDirectory() async {
    final appDir = await getExternalStorageDirectory();
    final aiDir = Directory(p.join(appDir!.path, 'ai_images'));
    if (!await aiDir.exists()) {
      await aiDir.create(recursive: true);
    }
    return aiDir;
  }

  void _updateState(AiGenerationState state) {
    if (!_generationController.isClosed) {
      _generationController.add(state);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HISTORY & CACHE
  // ═══════════════════════════════════════════════════════

  List<AiGeneratedImage> get history => List.unmodifiable(_history);

  Future<List<AiGeneratedImage>> loadSavedImages() async {
    final images = <AiGeneratedImage>[];

    try {
      final dir = await _getAiImagesDirectory();
      if (!await dir.exists()) return images;

      await for (final file in dir.list()) {
        if (file is File &&
            (file.path.endsWith('.png') || file.path.endsWith('.jpg'))) {
          final id = p.basenameWithoutExtension(file.path);
          final bytes = await file.readAsBytes();

          images.add(
            AiGeneratedImage(
              id: id,
              prompt: 'Saved image',
              localPath: file.path,
              bytes: bytes,
              width: 1024,
              height: 1024,
              createdAt: (await file.stat()).modified,
            ),
          );
        }
      }

      images.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('❌ Load saved images error: $e');
    }

    return images;
  }

  Future<bool> deleteImage(String id) async {
    try {
      final dir = await _getAiImagesDirectory();
      final file = File(p.join(dir.path, '$id.png'));

      if (await file.exists()) {
        await file.delete();
        _generatedImages.remove(id);
        _history.removeWhere((img) => img.id == id);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Delete image error: $e');
    }
    return false;
  }

  Future<void> clearHistory() async {
    try {
      final dir = await _getAiImagesDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
      _generatedImages.clear();
      _history.clear();
    } catch (e) {
      debugPrint('❌ Clear history error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PROMPT SUGGESTIONS
  // ═══════════════════════════════════════════════════════

  static const List<String> promptSuggestions = [
    'Beautiful sunset over mountains',
    'Futuristic city skyline at night',
    'Magical forest with glowing mushrooms',
    'Abstract colorful geometric patterns',
    'Cute cat astronaut in space',
    'Underwater coral reef scene',
    'Cozy coffee shop interior',
    'Northern lights over snowy landscape',
    'Steampunk mechanical dragon',
    'Peaceful zen garden with cherry blossoms',
    'Cyberpunk street scene with neon lights',
    'Majestic waterfall in tropical jungle',
    'Vintage car on Route 66',
    'Fantasy castle on floating island',
    'Minimalist modern architecture',
  ];

  static const List<String> negativePromptSuggestions = [
    'blurry, bad quality, distorted',
    'ugly, deformed, noisy, low resolution',
    'watermark, text, logo, signature',
    'oversaturated, overexposed',
    'cropped, out of frame',
  ];

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  void dispose() {
    _generationController.close();
    _httpClient.close();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ GENERATION STATE
// ═══════════════════════════════════════════════════════

enum AiGenerationStatus { idle, starting, generating, completed, failed }

class AiGenerationState {
  final AiGenerationStatus status;
  final double progress;
  final String message;
  final List<AiGeneratedImage>? images;
  final String? error;

  const AiGenerationState({
    required this.status,
    this.progress = 0.0,
    this.message = '',
    this.images,
    this.error,
  });

  factory AiGenerationState.idle() =>
      const AiGenerationState(status: AiGenerationStatus.idle);

  factory AiGenerationState.starting(String prompt) => AiGenerationState(
    status: AiGenerationStatus.starting,
    message: 'Starting generation for: $prompt',
  );

  factory AiGenerationState.generating(double progress, String message) =>
      AiGenerationState(
        status: AiGenerationStatus.generating,
        progress: progress,
        message: message,
      );

  factory AiGenerationState.completed(List<AiGeneratedImage> images) =>
      AiGenerationState(
        status: AiGenerationStatus.completed,
        progress: 1.0,
        message: 'Generated ${images.length} image(s)',
        images: images,
      );

  factory AiGenerationState.failed(String error) => AiGenerationState(
    status: AiGenerationStatus.failed,
    message: 'Generation failed',
    error: error,
  );

  bool get isGenerating =>
      status == AiGenerationStatus.starting ||
      status == AiGenerationStatus.generating;
}

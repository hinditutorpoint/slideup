import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/video_edit_settings.dart';
import '../services/ai_image_service.dart';

class AiTab extends StatefulWidget {
  final Function(ImageTimelineItem) onImageGenerated;
  final Duration videoDuration;
  final Duration currentPosition;

  const AiTab({
    super.key,
    required this.onImageGenerated,
    required this.videoDuration,
    required this.currentPosition,
  });

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> with SingleTickerProviderStateMixin {
  final AiImageService _aiService = AiImageService();
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  late TabController _tabController;

  static const String _providerKey = 'ai_provider';
  static const String _apiKeyKey = 'ai_api_key';

  AiImageStyle _selectedStyle = AiImageStyle.realistic;
  AiImageSize _selectedSize = AiImageSize.portrait; // Default to portrait (9:16 / 3:4) for reels
  AiProvider _selectedProvider = AiProvider.openRouter;
  int _imageCount = 1;

  List<AiGeneratedImage> _generatedImages = [];
  List<AiGeneratedImage> _savedImages = [];
  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _showProviderSettings = false;
  String? _error;

  AiGenerationState _generationState = AiGenerationState.idle();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedImages();
    _listenToGeneration();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final providerName = await _storage.read(key: _providerKey);
      final apiKey = await _storage.read(key: _apiKeyKey);
      if (!mounted) return;

      setState(() {
        if (providerName != null) {
          _selectedProvider = AiProvider.values.firstWhere(
            (p) => p.name == providerName,
            orElse: () => AiProvider.openRouter,
          );
        }
        if (apiKey != null && apiKey.isNotEmpty) {
          _apiKeyController.text = apiKey;
        } else {
          // If no API key is found, show settings by default so user can configure
          _showProviderSettings = true;
        }
      });

      if (apiKey != null && apiKey.isNotEmpty) {
        _aiService.configure(
          AiProviderConfig(provider: _selectedProvider, apiKey: apiKey),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load AI config: $e');
    }
  }

  Future<void> _saveAiConfig() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('Please enter an API key');
      return;
    }

    try {
      await _storage.write(key: _providerKey, value: _selectedProvider.name);
      await _storage.write(key: _apiKeyKey, value: apiKey);
      _aiService.configure(
        AiProviderConfig(provider: _selectedProvider, apiKey: apiKey),
      );
      setState(() {
        _showProviderSettings = false;
      });
      _showSnack('AI settings saved');
      HapticFeedback.selectionClick();
    } catch (e) {
      _showSnack('Failed to save settings: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  void _listenToGeneration() {
    _aiService.generationStream.listen((state) {
      if (mounted) {
        setState(() => _generationState = state);

        if (state.status == AiGenerationStatus.completed &&
            state.images != null) {
          setState(() {
            _generatedImages = [...state.images!, ..._generatedImages];
            _isLoading = false;
          });
          _loadSavedImages();
        } else if (state.status == AiGenerationStatus.failed) {
          setState(() {
            _error = state.error;
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _loadSavedImages() async {
    try {
      final saved = await _aiService.loadSavedImages();
      if (mounted) {
        setState(() => _savedImages = saved);
      }
    } catch (e) {
      debugPrint('❌ Load saved images error: $e');
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _apiKeyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),

          // Compact Header Bar
          _buildCompactHeader(),

          // Main View Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGenerateTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎯 COMPACT HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 6),
      child: Row(
        children: [
          // Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Compact Tab Pills
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: Colors.purpleAccent.shade400,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                const Tab(text: 'Generate'),
                Tab(text: 'History (${_savedImages.length})'),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Provider Config Gear Toggle
          IconButton(
            onPressed: () {
              setState(() => _showProviderSettings = !_showProviderSettings);
              HapticFeedback.selectionClick();
            },
            icon: Icon(
              Icons.tune_rounded,
              color: _showProviderSettings ? Colors.purpleAccent : Colors.white60,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'AI Provider Settings',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⚡ GENERATE TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable Provider Config
          if (_showProviderSettings) ...[
            _buildCompactProviderConfig(),
            const SizedBox(height: 10),
          ],

          // Prompt Input
          _buildCompactPromptInput(),
          const SizedBox(height: 8),

          // Quick ideas horizontal pills
          _buildCompactQuickPrompts(),
          const SizedBox(height: 10),

          // Style selection
          _buildCompactStyleSelection(),
          const SizedBox(height: 10),

          // Aspect ratio selection
          _buildCompactSizeSelection(),
          const SizedBox(height: 10),

          // Advanced options accordion
          if (_showAdvanced) ...[
            _buildCompactAdvancedOptions(),
            const SizedBox(height: 10),
          ],

          // Advanced toggle
          _buildAdvancedToggle(),
          const SizedBox(height: 12),

          // Generate button
          _buildCompactGenerateButton(),

          // Progress
          if (_generationState.isGenerating) ...[
            const SizedBox(height: 10),
            _buildCompactProgress(),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 8),
            _buildErrorMessage(),
          ],

          // Recent Generations
          if (_generatedImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRecentGenerations(),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⚙️ COMPACT PROVIDER CONFIG
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactProviderConfig() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: Colors.purpleAccent, size: 14),
              const SizedBox(width: 6),
              const Text(
                'AI Provider & API Key',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showProviderSettings = false),
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Provider Dropdown
              Expanded(
                flex: 4,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AiProvider>(
                      value: _selectedProvider,
                      dropdownColor: const Color(0xFF222228),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: AiProvider.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(_providerLabel(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (p) {
                        if (p != null) setState(() => _selectedProvider = p);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // API Key input
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'API Key...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Save button
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: _saveAiConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _providerLabel(AiProvider provider) {
    switch (provider) {
      case AiProvider.stabilityAi:
        return 'Stability AI';
      case AiProvider.openAi:
        return 'OpenAI DALL·E';
      case AiProvider.replicate:
        return 'Replicate';
      case AiProvider.deepAi:
        return 'DeepAI';
      case AiProvider.lexica:
        return 'Lexica';
      case AiProvider.openRouter:
        return 'OpenRouter';
      case AiProvider.cloudflare:
        return 'Cloudflare';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✍️ COMPACT PROMPT INPUT
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactPromptInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Describe image to generate (e.g. neon cyberpunk city in rain)...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
              contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_promptController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      _promptController.clear();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 10, color: Colors.white70),
                          SizedBox(width: 2),
                          Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 💡 COMPACT QUICK PROMPTS
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactQuickPrompts() {
    return SizedBox(
      height: 24,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AiImageService.promptSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = AiImageService.promptSuggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                _promptController.text = suggestion;
                setState(() {});
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  suggestion.length > 20 ? '${suggestion.substring(0, 20)}...' : suggestion,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎨 COMPACT STYLE SELECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactStyleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Style',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AiImageStyle.values.length,
            itemBuilder: (context, index) {
              final style = AiImageStyle.values[index];
              final isSelected = _selectedStyle == style;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStyle = style);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: 58,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purpleAccent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.purpleAccent : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStyleIcon(style),
                        color: isSelected ? Colors.purpleAccent : Colors.white60,
                        size: 16,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatStyleName(style),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 8.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getStyleIcon(AiImageStyle style) {
    switch (style) {
      case AiImageStyle.realistic:
        return Icons.camera_alt_outlined;
      case AiImageStyle.artistic:
        return Icons.palette_outlined;
      case AiImageStyle.anime:
        return Icons.face_outlined;
      case AiImageStyle.cartoon:
        return Icons.child_care_outlined;
      case AiImageStyle.sketch:
        return Icons.draw_outlined;
      case AiImageStyle.painting:
        return Icons.brush_outlined;
      case AiImageStyle.threeD:
        return Icons.view_in_ar_outlined;
      case AiImageStyle.abstract:
        return Icons.blur_on_outlined;
    }
  }

  String _formatStyleName(AiImageStyle style) {
    switch (style) {
      case AiImageStyle.threeD:
        return '3D';
      default:
        return style.name[0].toUpperCase() + style.name.substring(1);
    }
  }

  // ═══════════════════════════════════════════════════════
  // 📐 COMPACT SIZE / ASPECT RATIO
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactSizeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aspect Ratio',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: AiImageSize.values.map((size) {
            final isSelected = _selectedSize == size;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedSize = size);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purpleAccent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? Colors.purpleAccent : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSizeIcon(size, isSelected),
                      const SizedBox(width: 4),
                      Text(
                        _formatSizeName(size),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSizeIcon(AiImageSize size, bool isSelected) {
    double w = 10, h = 10;
    switch (size) {
      case AiImageSize.square:
        w = 9;
        h = 9;
        break;
      case AiImageSize.portrait:
        w = 7;
        h = 11;
        break;
      case AiImageSize.landscape:
        w = 11;
        h = 8;
        break;
      case AiImageSize.wide:
        w = 13;
        h = 7;
        break;
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.purpleAccent : Colors.white60,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  String _formatSizeName(AiImageSize size) {
    switch (size) {
      case AiImageSize.square:
        return '1:1';
      case AiImageSize.portrait:
        return '9:16';
      case AiImageSize.landscape:
        return '4:3';
      case AiImageSize.wide:
        return '16:9';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ⚙️ ADVANCED OPTIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactAdvancedOptions() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Negative prompt', style: TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 4),
          TextField(
            controller: _negativePromptController,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: InputDecoration(
              hintText: 'blurry, bad quality, watermark...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Image count: $_imageCount', style: const TextStyle(color: Colors.white60, fontSize: 10)),
              const Spacer(),
              GestureDetector(
                onTap: _imageCount > 1 ? () => setState(() => _imageCount--) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove, size: 12, color: Colors.white70),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_imageCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: _imageCount < 4 ? () => setState(() => _imageCount++) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showAdvanced = !_showAdvanced);
        HapticFeedback.selectionClick();
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showAdvanced ? 'Hide Advanced' : 'More Options',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            Icon(
              _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 14,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🚀 COMPACT GENERATE BUTTON
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactGenerateButton() {
    final canGenerate = _promptController.text.trim().isNotEmpty && !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: ElevatedButton(
        onPressed: canGenerate ? _generateImage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purpleAccent.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Generate AI Image',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompactProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _generationState.message,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: Colors.redAccent, size: 12),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🖼️ RECENT GENERATIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildRecentGenerations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generated (Tap to add to timeline)',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _generatedImages.length,
            itemBuilder: (context, index) {
              final image = _generatedImages[index];
              return GestureDetector(
                onTap: () => _addToTimeline(image),
                onLongPress: () => _showImageOptions(image),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageWidget(image),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.purpleAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📜 HISTORY TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    if (_savedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, color: Colors.white.withValues(alpha: 0.2), size: 36),
            const SizedBox(height: 8),
            const Text('No saved AI images yet', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _savedImages.length,
      itemBuilder: (context, index) {
        final image = _savedImages[index];
        return GestureDetector(
          onTap: () => _addToTimeline(image),
          onLongPress: () => _showImageOptions(image),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageWidget(image),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      color: Colors.black54,
                      child: Text(
                        image.prompt,
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(AiGeneratedImage image) {
    if (image.localPath != null) {
      return Image.file(
        File(image.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    } else if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    } else if (image.url != null) {
      return Image.network(
        image.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.image, color: Colors.white24, size: 24),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎬 ACTIONS
  // ═══════════════════════════════════════════════════════

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = AiImageRequest(
        prompt: prompt,
        negativePrompt: _negativePromptController.text.isNotEmpty
            ? _negativePromptController.text
            : null,
        style: _selectedStyle,
        size: _selectedSize,
        count: _imageCount,
      );

      await _aiService.generateImages(request);
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addToTimeline(AiGeneratedImage image) {
    try {
      final imagePath = image.localPath ?? image.url ?? '';
      if (imagePath.isEmpty && image.bytes == null) {
        _showSnack('Image not available');
        return;
      }

      final timelineItem = ImageTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: widget.currentPosition,
        endTime: widget.currentPosition + const Duration(seconds: 3),
        imagePath: imagePath,
        imageBytes: image.bytes,
        width: image.width,
        height: image.height,
        isAiGenerated: true,
        aiPrompt: image.prompt,
        scale: 0.4,
      );

      widget.onImageGenerated(timelineItem);
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Add to timeline error: $e');
      _showSnack('Failed to add image: $e');
    }
  }

  void _showImageOptions(AiGeneratedImage image) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222228),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(1.5)),
              ),
              const SizedBox(height: 10),
              Text(
                image.prompt,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add_circle, color: Colors.purpleAccent, size: 18),
                title: const Text('Add to Timeline', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToTimeline(image);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.copy, color: Colors.white70, size: 18),
                title: const Text('Use Prompt', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _promptController.text = image.prompt;
                  setState(() {});
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteImage(image);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteImage(AiGeneratedImage image) async {
    try {
      final success = await _aiService.deleteImage(image.id);
      if (success) {
        setState(() {
          _generatedImages.removeWhere((img) => img.id == image.id);
          _savedImages.removeWhere((img) => img.id == image.id);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('❌ Delete image error: $e');
    }
  }
}

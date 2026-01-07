import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late TabController _tabController;

  AiImageStyle _selectedStyle = AiImageStyle.realistic;
  AiImageSize _selectedSize = AiImageSize.landscape;
  int _imageCount = 1;

  List<AiGeneratedImage> _generatedImages = [];
  List<AiGeneratedImage> _savedImages = [];
  bool _isLoading = false;
  bool _showAdvanced = false;
  String? _error;

  AiGenerationState _generationState = AiGenerationState.idle();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedImages();
    _listenToGeneration();

    // Configure AI service (use your API key)
    // In production, load from secure storage
    _configureAiService();
  }

  void _configureAiService() {
    // Example: Configure with Stability AI
    // Replace with your actual API key
    _aiService.configure(
      AiProviderConfig(
        provider: AiProvider.stabilityAi,
        apiKey: 'YOUR_API_KEY', // Load from secure storage
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 450;

        return Column(
          children: [
            // Tabs
            _buildTabs(isCompact),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGenerateTab(isCompact),
                  _buildHistoryTab(isCompact),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs(bool isCompact) {
    return Container(
      margin: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.purple,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        labelStyle: TextStyle(
          fontSize: isCompact ? 12 : 13,
          fontWeight: FontWeight.bold,
        ),
        tabs: [
          Tab(
            icon: Icon(Icons.auto_awesome, size: isCompact ? 18 : 20),
            text: 'Generate',
          ),
          Tab(
            icon: Icon(Icons.history, size: isCompact ? 18 : 20),
            text: 'History (${_savedImages.length})',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildGenerateTab(bool isCompact) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt input
          _buildPromptInput(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Quick prompts
          _buildQuickPrompts(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Style selection
          _buildStyleSelection(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Size selection
          _buildSizeSelection(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Advanced options
          if (_showAdvanced) ...[
            _buildAdvancedOptions(isCompact),
            SizedBox(height: isCompact ? 12 : 16),
          ],

          // Advanced toggle
          _buildAdvancedToggle(isCompact),
          SizedBox(height: isCompact ? 16 : 20),

          // Generate button
          _buildGenerateButton(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Generation progress
          if (_generationState.isGenerating)
            _buildGenerationProgress(isCompact),

          // Error message
          if (_error != null) _buildErrorMessage(isCompact),

          // Recent generations
          if (_generatedImages.isNotEmpty) ...[
            SizedBox(height: isCompact ? 16 : 20),
            _buildRecentGenerations(isCompact),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptInput(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit, color: Colors.purple, size: isCompact ? 16 : 18),
            const SizedBox(width: 8),
            Text(
              'Describe your image',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : 10),
        TextField(
          controller: _promptController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
            hintText:
                'A beautiful sunset over mountains with dramatic clouds...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.purple),
            ),
            contentPadding: EdgeInsets.all(isCompact ? 12 : 14),
            suffixIcon: _promptController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _promptController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildQuickPrompts(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick ideas',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: isCompact ? 11 : 12,
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        SizedBox(
          height: isCompact ? 32 : 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AiImageService.promptSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = AiImageService.promptSuggestions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    suggestion.length > 25
                        ? '${suggestion.substring(0, 25)}...'
                        : suggestion,
                    style: TextStyle(fontSize: isCompact ? 10 : 11),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(color: Colors.white70),
                  onPressed: () {
                    _promptController.text = suggestion;
                    setState(() {});
                    HapticFeedback.selectionClick();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Style',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 10),
        SizedBox(
          height: isCompact ? 70 : 80,
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
                  width: isCompact ? 70 : 80,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purple.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.purple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStyleIcon(style),
                        color: isSelected ? Colors.purple : Colors.white70,
                        size: isCompact ? 22 : 26,
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                      Text(
                        _formatStyleName(style),
                        style: TextStyle(
                          color: isSelected ? Colors.purple : Colors.white70,
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
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
        return Icons.camera_alt;
      case AiImageStyle.artistic:
        return Icons.palette;
      case AiImageStyle.anime:
        return Icons.face;
      case AiImageStyle.cartoon:
        return Icons.child_care;
      case AiImageStyle.sketch:
        return Icons.edit;
      case AiImageStyle.painting:
        return Icons.brush;
      case AiImageStyle.threeD:
        return Icons.view_in_ar;
      case AiImageStyle.abstract:
        return Icons.blur_on;
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

  Widget _buildSizeSelection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Size',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 10),
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
                  margin: const EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purple.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.purple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSizePreview(size, isCompact),
                      SizedBox(height: isCompact ? 4 : 6),
                      Text(
                        _formatSizeName(size),
                        style: TextStyle(
                          color: isSelected ? Colors.purple : Colors.white70,
                          fontSize: isCompact ? 9 : 10,
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

  Widget _buildSizePreview(AiImageSize size, bool isCompact) {
    double w, h;
    switch (size) {
      case AiImageSize.square:
        w = h = isCompact ? 20 : 24;
        break;
      case AiImageSize.portrait:
        w = isCompact ? 16 : 18;
        h = isCompact ? 22 : 26;
        break;
      case AiImageSize.landscape:
        w = isCompact ? 24 : 28;
        h = isCompact ? 16 : 18;
        break;
      case AiImageSize.wide:
        w = isCompact ? 28 : 32;
        h = isCompact ? 14 : 16;
        break;
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _formatSizeName(AiImageSize size) {
    switch (size) {
      case AiImageSize.square:
        return '1:1';
      case AiImageSize.portrait:
        return '3:4';
      case AiImageSize.landscape:
        return '4:3';
      case AiImageSize.wide:
        return '16:9';
    }
  }

  Widget _buildAdvancedOptions(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Negative prompt
        Text(
          'Negative prompt (what to avoid)',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: isCompact ? 11 : 12,
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        TextField(
          controller: _negativePromptController,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'blurry, bad quality, distorted...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(isCompact ? 10 : 12),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 14),

        // Image count
        Row(
          children: [
            Text(
              'Number of images: $_imageCount',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isCompact ? 11 : 12,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _imageCount > 1
                  ? () => setState(() => _imageCount--)
                  : null,
              icon: Icon(
                Icons.remove_circle_outline,
                size: isCompact ? 20 : 22,
              ),
              color: _imageCount > 1 ? Colors.white70 : Colors.grey[700],
            ),
            Text(
              '$_imageCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            IconButton(
              onPressed: _imageCount < 4
                  ? () => setState(() => _imageCount++)
                  : null,
              icon: Icon(Icons.add_circle_outline, size: isCompact ? 20 : 22),
              color: _imageCount < 4 ? Colors.white70 : Colors.grey[700],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle(bool isCompact) {
    return GestureDetector(
      onTap: () {
        setState(() => _showAdvanced = !_showAdvanced);
        HapticFeedback.selectionClick();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showAdvanced ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey[400],
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 4),
          Text(
            _showAdvanced ? 'Hide advanced options' : 'Show advanced options',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isCompact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(bool isCompact) {
    final canGenerate =
        _promptController.text.trim().isNotEmpty &&
        !_isLoading &&
        _aiService.isConfigured;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canGenerate ? _generateImage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[800],
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: isCompact ? 18 : 20,
                height: isCompact ? 18 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(Icons.auto_awesome, size: isCompact ? 18 : 20),
            SizedBox(width: isCompact ? 8 : 10),
            Text(
              _isLoading ? 'Generating...' : 'Generate Image',
              style: TextStyle(
                fontSize: isCompact ? 14 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationProgress(bool isCompact) {
    return Container(
      margin: EdgeInsets.only(top: isCompact ? 12 : 16),
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _generationState.progress > 0
                      ? _generationState.progress
                      : null,
                  strokeWidth: 2,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _generationState.message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                  ),
                ),
              ),
              if (_generationState.progress > 0)
                Text(
                  '${(_generationState.progress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: isCompact ? 12 : 13,
                  ),
                ),
            ],
          ),
          if (_generationState.progress > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _generationState.progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.purple),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(bool isCompact) {
    return Container(
      margin: EdgeInsets.only(top: isCompact ? 12 : 16),
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: isCompact ? 20 : 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: isCompact ? 12 : 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGenerations(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Generations',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 10 : 12),
        SizedBox(
          height: isCompact ? 100 : 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _generatedImages.length.clamp(0, 10),
            itemBuilder: (context, index) {
              return _buildImageThumbnail(_generatedImages[index], isCompact);
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HISTORY TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildHistoryTab(bool isCompact) {
    if (_savedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.grey[700],
              size: isCompact ? 48 : 56,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              'No AI images yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 8),
            Text(
              'Generate your first image!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isCompact ? 12 : 13,
              ),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 3;

    return GridView.builder(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isCompact ? 8 : 10,
        mainAxisSpacing: isCompact ? 8 : 10,
        childAspectRatio: 1,
      ),
      itemCount: _savedImages.length,
      itemBuilder: (context, index) {
        return _buildHistoryImageCard(_savedImages[index], isCompact);
      },
    );
  }

  Widget _buildImageThumbnail(AiGeneratedImage image, bool isCompact) {
    return GestureDetector(
      onTap: () => _addToTimeline(image),
      onLongPress: () => _showImageOptions(image),
      child: Container(
        width: isCompact ? 100 : 120,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImageWidget(image),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.add_circle,
                    color: Colors.purple,
                    size: isCompact ? 20 : 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryImageCard(AiGeneratedImage image, bool isCompact) {
    return GestureDetector(
      onTap: () => _addToTimeline(image),
      onLongPress: () => _showImageOptions(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImageWidget(image),
              // Overlay with prompt
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 6 : 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    image.prompt,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 8 : 9,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Add button
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: isCompact ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: Colors.purple,
            ),
          );
        },
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(Icons.image, color: Colors.grey[600], size: 32),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final timelineItem = ImageTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: widget.currentPosition,
        endTime: widget.currentPosition + const Duration(seconds: 5),
        imagePath: imagePath,
        imageBytes: image.bytes,
        width: image.width,
        height: image.height,
        isAiGenerated: true,
        aiPrompt: image.prompt,
        scale: 0.5,
      );

      widget.onImageGenerated(timelineItem);
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image added to timeline'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('❌ Add to timeline error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageOptions(AiGeneratedImage image) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Generated Image',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                image.prompt,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildOptionTile(Icons.add_circle, 'Add to Timeline', () {
                Navigator.pop(ctx);
                _addToTimeline(image);
              }),
              _buildOptionTile(Icons.copy, 'Use Prompt', () {
                Navigator.pop(ctx);
                _promptController.text = image.prompt;
                setState(() {});
                HapticFeedback.selectionClick();
              }),
              _buildOptionTile(Icons.delete, 'Delete', () {
                Navigator.pop(ctx);
                _deleteImage(image);
              }, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 15,
                ),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deleted'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Delete image error: $e');
    }
  }
}

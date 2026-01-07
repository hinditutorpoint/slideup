import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/video_edit_settings.dart';
import '../services/pixabay_api_service.dart';

class MusicTab extends StatefulWidget {
  final String? selectedMusicPath;
  final Function(String?) onMusicChanged;
  final Function(MusicTrack) onMusicSelected;

  const MusicTab({
    super.key,
    required this.selectedMusicPath,
    required this.onMusicChanged,
    required this.onMusicSelected,
  });

  @override
  State<MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<MusicTab>
    with SingleTickerProviderStateMixin {
  final PixabayApiService _apiService = PixabayApiService();
  late TabController _categoryController;

  List<MusicTrack> _tracks = [];
  List<MusicTrack> _downloadedTracks = [];
  bool _isLoading = false;
  String? _error;
  MusicCategory _selectedCategory = MusicCategory.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String? _playingTrackId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  final Map<String, double> _downloadProgress = {};
  bool _showDownloaded = false;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(
      length: MusicCategory.values.length,
      vsync: this,
    );
    _categoryController.addListener(_onCategoryChanged);
    _setupPlayerListeners();
    _loadTracks();
    _loadDownloadedTracks();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _debounce?.cancel();
    try {
      _apiService.stopPreview();
    } catch (_) {}
    super.dispose();
  }

  void _setupPlayerListeners() {
    try {
      _positionSub = _apiService.positionStream.listen((pos) {
        if (mounted) setState(() => _currentPosition = pos);
      });

      _playerStateSub = _apiService.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _playingTrackId = _apiService.currentPlayingId;
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Setup player error: $e');
    }
  }

  void _onCategoryChanged() {
    if (_categoryController.indexIsChanging) return;
    try {
      setState(
        () =>
            _selectedCategory = MusicCategory.values[_categoryController.index],
      );
      _loadTracks();
    } catch (e) {
      debugPrint('❌ Category change error: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _searchQuery = value);
        _loadTracks();
      }
    });
  }

  Future<void> _loadTracks() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tracks = await _apiService.fetchMusic(
        query: _searchQuery,
        category: _selectedCategory,
      );

      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load tracks error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load music';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDownloadedTracks() async {
    try {
      final downloaded = await _apiService.getDownloadedMusic();
      if (mounted) setState(() => _downloadedTracks = downloaded);
    } catch (e) {
      debugPrint('❌ Load downloaded error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 400;

        return Column(
          children: [
            _buildHeader(isCompact),
            _buildSearchBar(isCompact),
            if (!_showDownloaded) _buildCategoryTabs(isCompact),
            Expanded(
              child: _showDownloaded
                  ? _buildDownloadedList(isCompact)
                  : _isLoading
                  ? _buildLoadingState()
                  : _error != null
                  ? _buildErrorState(isCompact)
                  : _buildTracksList(isCompact),
            ),
            if (widget.selectedMusicPath != null) _buildSelectedBar(isCompact),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggle('Browse', !_showDownloaded, () {
                  setState(() => _showDownloaded = false);
                  HapticFeedback.selectionClick();
                }, isCompact),
                _buildToggle(
                  'Downloaded (${_downloadedTracks.length})',
                  _showDownloaded,
                  () {
                    setState(() => _showDownloaded = true);
                    _loadDownloadedTracks();
                    HapticFeedback.selectionClick();
                  },
                  isCompact,
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_isPlaying)
            IconButton(
              onPressed: () {
                try {
                  _apiService.stopPreview();
                } catch (_) {}
              },
              icon: Icon(
                Icons.stop,
                size: isCompact ? 18 : 20,
                color: Colors.red,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          IconButton(
            onPressed: _showDownloaded ? _loadDownloadedTracks : _loadTracks,
            icon: Icon(
              Icons.refresh,
              size: isCompact ? 18 : 20,
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String label,
    bool active,
    VoidCallback onTap,
    bool isCompact,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey[400],
            fontSize: isCompact ? 10 : 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _showDownloaded
              ? 'Search downloaded...'
              : 'Search music (e.g., chill, rock, piano)...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: isCompact ? 18 : 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[500],
                    size: isCompact ? 18 : 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    if (!_showDownloaded) _loadTracks();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
        ),
        onChanged: _showDownloaded
            ? (v) => setState(() => _searchQuery = v)
            : _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: _showDownloaded
            ? null
            : (v) {
                setState(() => _searchQuery = v);
                _loadTracks();
              },
      ),
    );
  }

  Widget _buildCategoryTabs(bool isCompact) {
    return SizedBox(
      height: isCompact ? 32 : 36,
      child: TabBar(
        controller: _categoryController,
        isScrollable: true,
        indicatorColor: Colors.red,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: TextStyle(fontSize: isCompact ? 10 : 11),
        indicatorSize: TabBarIndicatorSize.label,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: MusicCategory.values.map((cat) {
          return Tab(text: _formatCategory(cat));
        }).toList(),
      ),
    );
  }

  String _formatCategory(MusicCategory cat) {
    if (cat == MusicCategory.all) return 'All';
    if (cat == MusicCategory.hiphop) return 'Hip Hop';
    return cat.name[0].toUpperCase() + cat.name.substring(1);
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }

  Widget _buildErrorState(bool isCompact) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: isCompact ? 40 : 48,
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            _error ?? 'Error',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isCompact ? 13 : 14,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          TextButton(onPressed: _loadTracks, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTracksList(bool isCompact) {
    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              color: Colors.grey[700],
              size: isCompact ? 40 : 48,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No music found',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 13 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: isCompact ? 4 : 8),
              Text(
                'Try different keywords',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTracks,
      color: Colors.red,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          try {
            return _buildTrackCard(_tracks[index], isCompact);
          } catch (e) {
            debugPrint('❌ Build track error: $e');
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildDownloadedList(bool isCompact) {
    var filtered = _downloadedTracks;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = _downloadedTracks
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q),
          )
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done,
              color: Colors.grey[700],
              size: isCompact ? 40 : 48,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results' : 'No downloaded music',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 13 : 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        try {
          return _buildTrackCard(
            filtered[index],
            isCompact,
            isDownloadedView: true,
          );
        } catch (e) {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildTrackCard(
    MusicTrack track,
    bool isCompact, {
    bool isDownloadedView = false,
  }) {
    final isCurrentTrack = _playingTrackId == track.id;
    final isDownloading = _downloadProgress.containsKey(track.id);
    final progress = _downloadProgress[track.id] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: isCurrentTrack
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentTrack
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playPreview(track),
          onLongPress: () => _showTrackActions(track, isDownloadedView),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            child: Row(
              children: [
                // Album art
                _buildAlbumArt(track, isCurrentTrack, isCompact),
                SizedBox(width: isCompact ? 10 : 12),

                // Info
                Expanded(
                  child: _buildTrackInfo(track, isCurrentTrack, isCompact),
                ),

                // Actions
                _buildActions(track, isDownloading, progress, isCompact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MusicTrack track, bool isCurrentTrack, bool isCompact) {
    final size = isCompact ? 48.0 : 56.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.albumArt != null && track.albumArt!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: track.albumArt!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _albumPlaceholder(size),
                  errorWidget: (_, __, ___) => _albumPlaceholder(size),
                )
              : _albumPlaceholder(size),
        ),
        Container(
          width: isCompact ? 26 : 30,
          height: isCompact ? 26 : 30,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCurrentTrack && _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: isCompact ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _albumPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Icon(Icons.music_note, color: Colors.grey[600], size: size * 0.4),
    );
  }

  Widget _buildTrackInfo(
    MusicTrack track,
    bool isCurrentTrack,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          track.artist,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isCompact ? 11 : 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Row(
          children: [
            Text(
              _formatDuration(track.duration),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isCompact ? 10 : 11,
              ),
            ),
            if (track.downloads > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.download, size: 10, color: Colors.grey[600]),
              const SizedBox(width: 2),
              Text(
                _formatNumber(track.downloads),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 9 : 10,
                ),
              ),
            ],
          ],
        ),
        // Tags
        if (track.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: track.tags.take(3).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: Colors.grey[500], fontSize: 9),
                  ),
                );
              }).toList(),
            ),
          ),
        // Progress bar
        if (isCurrentTrack && _isPlaying)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(
              value: track.duration.inMilliseconds > 0
                  ? (_currentPosition.inMilliseconds /
                            track.duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                  : 0,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.red),
              minHeight: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildActions(
    MusicTrack track,
    bool isDownloading,
    double progress,
    bool isCompact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDownloading)
          SizedBox(
            width: isCompact ? 32 : 36,
            height: isCompact ? 32 : 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  color: Colors.red,
                ),
                Text(
                  '${(progress * 100).toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ],
            ),
          )
        else if (track.isDownloaded)
          IconButton(
            onPressed: () => _useTrack(track),
            icon: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: isCompact ? 22 : 24,
            ),
            tooltip: 'Use',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isCompact ? 32 : 36,
              minHeight: isCompact ? 32 : 36,
            ),
          )
        else
          IconButton(
            onPressed: () => _downloadTrack(track),
            icon: Icon(
              Icons.download,
              color: Colors.white70,
              size: isCompact ? 20 : 22,
            ),
            tooltip: 'Download',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isCompact ? 32 : 36,
              minHeight: isCompact ? 32 : 36,
            ),
          ),

        if (track.isDownloaded)
          IconButton(
            onPressed: () => _useTrack(track),
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.red,
              size: isCompact ? 20 : 22,
            ),
            tooltip: 'Add',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isCompact ? 32 : 36,
              minHeight: isCompact ? 32 : 36,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedBar(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note,
            color: Colors.green,
            size: isCompact ? 20 : 24,
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Music selected',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.selectedMusicPath?.split('/').last ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isCompact ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              widget.onMusicChanged(null);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              Icons.close,
              color: Colors.red,
              size: isCompact ? 18 : 20,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════

  Future<void> _playPreview(MusicTrack track) async {
    try {
      await _apiService.playPreview(track);
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('❌ Play error: $e');
    }
  }

  Future<void> _downloadTrack(MusicTrack track) async {
    try {
      setState(() => _downloadProgress[track.id] = 0);

      final result = await _apiService.downloadMusic(
        track,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[track.id] = p);
        },
      );

      setState(() => _downloadProgress.remove(track.id));

      if (result != null) {
        final index = _tracks.indexWhere((t) => t.id == track.id);
        if (index >= 0 && mounted) {
          setState(() => _tracks[index] = result);
        }
        await _loadDownloadedTracks();
        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${track.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      setState(() => _downloadProgress.remove(track.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _useTrack(MusicTrack track) {
    try {
      if (track.localPath != null) {
        widget.onMusicChanged(track.localPath);
        widget.onMusicSelected(track);
        _apiService.stopPreview();
        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added: ${track.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Use track error: $e');
    }
  }

  void _showTrackActions(MusicTrack track, bool isDownloadedView) {
    try {
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
                  track.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  track.artist,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),
                _actionTile(Icons.play_arrow, 'Play Preview', () {
                  Navigator.pop(ctx);
                  _playPreview(track);
                }),
                if (!track.isDownloaded)
                  _actionTile(Icons.download, 'Download', () {
                    Navigator.pop(ctx);
                    _downloadTrack(track);
                  }),
                if (track.isDownloaded) ...[
                  _actionTile(Icons.add_circle, 'Add to Video', () {
                    Navigator.pop(ctx);
                    _useTrack(track);
                  }),
                  _actionTile(Icons.delete, 'Delete Download', () {
                    Navigator.pop(ctx);
                    _deleteTrack(track);
                  }, isDestructive: true),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Show actions error: $e');
    }
  }

  Widget _actionTile(
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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

  Future<void> _deleteTrack(MusicTrack track) async {
    try {
      final success = await _apiService.deleteMusicDownload(track.id);
      if (success) {
        final index = _tracks.indexWhere((t) => t.id == track.id);
        if (index >= 0 && mounted) {
          setState(
            () => _tracks[index] = track.copyWith(
              isDownloaded: false,
              localPath: null,
            ),
          );
        }
        await _loadDownloadedTracks();

        if (widget.selectedMusicPath == track.localPath) {
          widget.onMusicChanged(null);
        }

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
      debugPrint('❌ Delete error: $e');
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

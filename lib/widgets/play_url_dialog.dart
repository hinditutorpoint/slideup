import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../models/url_history.dart';
import '../services/database_service.dart';

class PlayUrlDialog extends StatefulWidget {
  const PlayUrlDialog({super.key});

  @override
  State<PlayUrlDialog> createState() => _PlayUrlDialogState();
}

class _PlayUrlDialogState extends State<PlayUrlDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _titleController = TextEditingController();
  late TabController _tabController;
  bool _loading = false;
  List<UrlHistory> _history = [];
  List<UrlHistory> _favorites = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await DatabaseService.instance.getUrlHistory();
      final favorites = await DatabaseService.instance.getFavoriteUrls();
      setState(() {
        _history = history;
        _favorites = favorites;
        _loadingHistory = false;
      });
    } catch (e) {
      setState(() => _loadingHistory = false);
      if (mounted) {
        _showError('Failed to load history: $e');
      }
    }
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        ['http', 'https', 'rtsp', 'rtmp'].contains(uri.scheme);
  }

  String _detectMimeType(String url) {
    final lower = url.toLowerCase();

    if (lower.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (lower.endsWith('.mpd')) return 'application/dash+xml';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.flac')) return 'audio/flac';

    return 'application/octet-stream';
  }

  MediaType _detectMediaType(String mime) {
    if (mime.startsWith('video/') ||
        mime.startsWith('application/vnd.apple.mpegurl') ||
        mime.startsWith('application/dash+xml'))
      return MediaType.video;
    if (mime.startsWith('audio/')) return MediaType.audio;
    return MediaType.other;
  }

  String _extractFileName(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return 'Stream from URL';
  }

  Future<void> _play({String? url, String? title}) async {
    final urlToPlay = url ?? _controller.text.trim();
    final titleToUse = title ?? _titleController.text.trim();

    if (!_isValidUrl(urlToPlay)) {
      _showError('Invalid URL');
      return;
    }

    setState(() => _loading = true);

    try {
      final mime = _detectMimeType(urlToPlay);
      final mediaType = _detectMediaType(mime);
      final fileName = titleToUse.isNotEmpty
          ? titleToUse
          : _extractFileName(urlToPlay);

      // Check if URL exists in history
      final existing = await DatabaseService.instance.getUrlHistoryByUrl(
        urlToPlay,
      );

      if (existing != null) {
        // Update existing entry
        final updated = existing.copyWith(
          lastPlayed: DateTime.now(),
          playCount: existing.playCount + 1,
          title: titleToUse.isNotEmpty ? titleToUse : existing.title,
        );
        await DatabaseService.instance.updateUrlHistory(updated);
      } else {
        // Create new entry
        final urlHistory = UrlHistory(
          id: 'url_${DateTime.now().millisecondsSinceEpoch}',
          url: urlToPlay,
          title: titleToUse.isNotEmpty ? titleToUse : null,
          mimeType: mime,
          mediaType: mediaType,
          lastPlayed: DateTime.now(),
          playCount: 1,
        );
        await DatabaseService.instance.saveUrlHistory(urlHistory);
      }

      final mediaFile = MediaFile(
        id: 'url_${DateTime.now().millisecondsSinceEpoch}',
        name: fileName,
        path: urlToPlay,
        displayPath: urlToPlay,
        type: mediaType,
        size: 0,
        dateModified: DateTime.now(),
        dateAdded: DateTime.now(),
        mimeType: mime,
      );

      if (!mounted) return;
      Navigator.pop(context, mediaFile);
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error: $e');
    }
  }

  Future<void> _toggleFavorite(UrlHistory urlHistory) async {
    final updated = urlHistory.copyWith(isFavorite: !urlHistory.isFavorite);
    await DatabaseService.instance.updateUrlHistory(updated);
    _loadHistory();
  }

  Future<void> _deleteHistoryItem(UrlHistory urlHistory) async {
    await DatabaseService.instance.deleteUrlHistory(urlHistory.id);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all URL history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.clearUrlHistory();
      _loadHistory();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play from URL'),
        actions: [
          if (_tabController.index == 0 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
              tooltip: 'Clear History',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.add_link), text: 'New URL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildHistoryTab(), _buildNewUrlTab()],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No URL history',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Add a new URL'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return _buildHistoryItem(item);
        },
      ),
    );
  }

  Widget _buildHistoryItem(UrlHistory item) {
    IconData typeIcon;
    Color typeColor;

    switch (item.mediaType) {
      case MediaType.video:
        typeIcon = Icons.video_library;
        typeColor = Colors.blue;
        break;
      case MediaType.audio:
        typeIcon = Icons.audio_file;
        typeColor = Colors.orange;
        break;
      default:
        typeIcon = Icons.link;
        typeColor = Colors.grey;
    }

    return Dismissible(
      key: Key(item.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteHistoryItem(item),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.2),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          item.title ?? item.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Played ${item.playCount} time${item.playCount > 1 ? 's' : ''} • ${_formatDate(item.lastPlayed)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            item.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: item.isFavorite ? Colors.red : null,
          ),
          onPressed: () => _toggleFavorite(item),
        ),
        onTap: _loading ? null : () => _play(url: item.url, title: item.title),
      ),
    );
  }

  Widget _buildNewUrlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_favorites.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.red[400]),
                const SizedBox(width: 8),
                const Text(
                  'Favorites',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final fav = _favorites[index];
                  return _buildFavoriteChip(fav);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title (Optional)',
              hintText: 'My Stream',
              prefixIcon: const Icon(Icons.label),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: _favorites.isEmpty,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com/video.m3u8',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _loading ? null : _play(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Supported Formats:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFormatChip('HLS (.m3u8)'),
              _buildFormatChip('DASH (.mpd)'),
              _buildFormatChip('MP4'),
              _buildFormatChip('MKV'),
              _buildFormatChip('MP3'),
              _buildFormatChip('FLAC'),
              _buildFormatChip('RTSP/RTMP'),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loading || _controller.text.isEmpty ? null : _play,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_loading ? 'Loading...' : 'Play'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteChip(UrlHistory fav) {
    return InkWell(
      onTap: () => _play(url: fav.url, title: fav.title),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fav.mediaType == MediaType.video
                  ? Icons.video_library
                  : Icons.audio_file,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              fav.title ?? 'Stream',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

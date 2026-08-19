import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:share_plus/share_plus.dart';

import '../documents/models/download_task.dart';
import '../documents/screens/unified_reader_screen.dart';
import '../video_player/video_player_launcher.dart';
import '../../helpers/audio_playback_helper.dart';
import '../../models/media_file.dart';
import '../../providers/download_providers.dart';
import '../../screens/auth_screen.dart';
import '../../services/security_service.dart';
import 'media_intercept_helper.dart';

/// Comprehensive browser downloads manager screen supporting Queue,
/// Live Downloading, and Downloaded completed items with full action suite:
/// download/retry, pause, resume, cancel, share, delete, properties, lock/unlock.
class BrowserDownloadsScreen extends ConsumerStatefulWidget {
  const BrowserDownloadsScreen({super.key});

  @override
  ConsumerState<BrowserDownloadsScreen> createState() =>
      _BrowserDownloadsScreenState();
}

class _BrowserDownloadsScreenState extends ConsumerState<BrowserDownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'video', 'audio', 'document', 'other'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadsState = ref.watch(downloadsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allDownloads = downloadsState.downloads;

    // Filter by search query and type filter
    final filtered = allDownloads.where((task) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(q);
        final matchesFile = task.fileName.toLowerCase().contains(q);
        if (!matchesTitle && !matchesFile) return false;
      }

      if (_typeFilter != 'all') {
        final type = _detectMediaType(task.fileName, task.mediaType);
        if (type != _typeFilter) return false;
      }

      return true;
    }).toList();

    // 1. Queue: pending tasks
    final queueTasks = filtered
        .where((t) => t.status == DownloadStatus.pending)
        .toList();

    // 2. Downloading: active in-progress & paused & failed tasks
    final downloadingTasks = filtered
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.paused ||
              t.status == DownloadStatus.failed,
        )
        .toList();

    // 3. Downloaded: completed tasks
    final downloadedTasks = filtered
        .where((t) => t.status == DownloadStatus.completed)
        .toList();

    final activeCount = allDownloads
        .where((t) => t.status == DownloadStatus.downloading)
        .length;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101216)
          : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Downloads',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeCount active',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add from URL',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _promptForUrl,
          ),
          PopupMenuButton<String>(
            tooltip: 'Download options',
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _handleGlobalAction(value, allDownloads),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pause_all',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Pause All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Resume All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 18, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('Cancel All Active'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Clear Completed List'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(98),
          child: Column(
            children: [
              // Search & Filter row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E222B)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search downloads...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.grey,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterMenu(),
                  ],
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.teal,
                indicatorWeight: 3,
                labelColor: Colors.teal,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Queue',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (queueTasks.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _buildBadge(queueTasks.length, Colors.blueGrey),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Downloading',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (downloadingTasks.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _buildBadge(downloadingTasks.length, Colors.teal),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Downloaded',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (downloadedTasks.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _buildBadge(downloadedTasks.length, Colors.green),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Queue Tab
          _buildQueueList(queueTasks, isDark),
          // 2. Downloading Tab
          _buildDownloadingList(downloadingTasks, isDark),
          // 3. Downloaded Tab
          _buildDownloadedList(downloadedTasks, isDark),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Filter by media type',
      icon: Icon(
        Icons.filter_list_rounded,
        size: 20,
        color: _typeFilter == 'all' ? Colors.grey : Colors.teal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) => setState(() => _typeFilter = val),
      itemBuilder: (context) => [
        _filterMenuItem('all', 'All Files', Icons.folder_open),
        _filterMenuItem('video', 'Videos', Icons.videocam),
        _filterMenuItem('audio', 'Audio', Icons.audiotrack),
        _filterMenuItem('document', 'Documents', Icons.description),
        _filterMenuItem('other', 'Others', Icons.insert_drive_file),
      ],
    );
  }

  PopupMenuItem<String> _filterMenuItem(
    String value,
    String label,
    IconData icon,
  ) {
    final selected = _typeFilter == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? Colors.teal : Colors.grey[700],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.teal : null,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check, size: 16, color: Colors.teal),
        ],
      ),
    );
  }

  // ─── Tab 1: Queue List ──────────────────────────────────────────────────────

  Widget _buildQueueList(List<DownloadTask> tasks, bool isDark) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.hourglass_empty_rounded,
        title: 'Queue is Empty',
        subtitle: 'Tasks waiting to be downloaded will appear here',
        isDark: isDark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(
          task: task,
          isDark: isDark,
          trailingActions: [
            IconButton(
              tooltip: 'Start Now',
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.teal),
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).resumeDownload(task.id),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).cancelDownload(task.id),
            ),
          ],
        );
      },
    );
  }

  // ─── Tab 2: Downloading List ───────────────────────────────────────────────

  Widget _buildDownloadingList(List<DownloadTask> tasks, bool isDark) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download_done_rounded,
        title: 'No Active Downloads',
        subtitle: 'Ongoing or paused downloads will appear here',
        isDark: isDark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _DownloadingTaskItem(
          key: ValueKey(task.id),
          task: task,
          isDark: isDark,
          onPause: () =>
              ref.read(downloadsProvider.notifier).pauseDownload(task.id),
          onResume: () =>
              ref.read(downloadsProvider.notifier).resumeDownload(task.id),
          onRetry: () =>
              ref.read(downloadsProvider.notifier).retryDownload(task.id),
          onCancel: () =>
              ref.read(downloadsProvider.notifier).cancelDownload(task.id),
          onDelete: () => _confirmDelete(task),
          onProperties: () => _showPropertiesSheet(task),
        );
      },
    );
  }

  // ─── Tab 3: Downloaded List ────────────────────────────────────────────────

  Widget _buildDownloadedList(List<DownloadTask> tasks, bool isDark) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_zip_outlined,
        title: 'No Downloaded Files',
        subtitle: 'Completed downloads will appear here',
        isDark: isDark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isLocked = _isTaskLocked(task);

        return _buildDownloadedCard(
          task: task,
          isLocked: isLocked,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildDownloadedCard({
    required DownloadTask task,
    required bool isLocked,
    required bool isDark,
  }) {
    final mediaType = _detectMediaType(task.fileName, task.mediaType);
    final color = _getMediaColor(mediaType);
    final icon = _getMediaIcon(mediaType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLocked
              ? Colors.amber.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF262A34) : Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      color: isDark ? const Color(0xFF1B1E26) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDownloadedFile(task),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon with locked indicator
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.amber.withValues(alpha: 0.15)
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isLocked ? Colors.amber : color,
                      size: 24,
                    ),
                  ),
                  if (isLocked)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.isNotEmpty ? task.title : task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          task.formattedSize,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                        Text(
                          _formatDate(task.completedAt ?? task.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LOCKED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action menu
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (action) =>
                    _handleDownloadedAction(action, task, isLocked),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 18, color: Colors.teal),
                        SizedBox(width: 10),
                        Text('Open / Play'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('Share'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: isLocked ? 'unlock' : 'lock',
                    child: Row(
                      children: [
                        Icon(
                          isLocked
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: isLocked ? Colors.green : Colors.amber,
                        ),
                        const SizedBox(width: 10),
                        Text(isLocked ? 'Unlock File' : 'Lock File in Vault'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'properties',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Properties'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required DownloadTask task,
    required bool isDark,
    required List<Widget> trailingActions,
  }) {
    final mediaType = _detectMediaType(task.fileName, task.mediaType);
    final color = _getMediaColor(mediaType);
    final icon = _getMediaIcon(mediaType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF262A34) : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      color: isDark ? const Color(0xFF1B1E26) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isNotEmpty ? task.title : task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Queued • ${task.formattedSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: trailingActions),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1E26)
                    : Colors.teal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: isDark ? Colors.grey[500] : Colors.teal[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions & Handlers ───────────────────────────────────────────────────

  void _handleGlobalAction(String action, List<DownloadTask> allDownloads) {
    final notifier = ref.read(downloadsProvider.notifier);
    switch (action) {
      case 'pause_all':
        for (final t in allDownloads) {
          if (t.status == DownloadStatus.downloading) {
            notifier.pauseDownload(t.id);
          }
        }
        break;
      case 'resume_all':
        for (final t in allDownloads) {
          if (t.status == DownloadStatus.paused ||
              t.status == DownloadStatus.failed) {
            notifier.resumeDownload(t.id);
          }
        }
        break;
      case 'cancel_all':
        for (final t in allDownloads) {
          if (t.isActive || t.status == DownloadStatus.paused) {
            notifier.cancelDownload(t.id);
          }
        }
        break;
      case 'clear_completed':
        for (final t in allDownloads) {
          if (t.status == DownloadStatus.completed) {
            notifier.deleteDownload(t.id, deleteFile: false);
          }
        }
        break;
    }
  }

  Future<void> _promptForUrl() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add from URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: 'https://example.com/media.mp4',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onSubmitted: (v) => Navigator.pop(dialogCtx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (entered == null || entered.isEmpty) return;

    var raw = entered;
    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _showSnack('Invalid URL');
      return;
    }

    if (isMediaUri(uri)) {
      await showMediaActionSheet(context, ref, uri);
    } else {
      _showSnack('Not a media URL (video/audio/document/playlist)');
    }
  }

  void _handleDownloadedAction(
    String action,
    DownloadTask task,
    bool isLocked,
  ) {
    switch (action) {
      case 'play':
        _openDownloadedFile(task);
        break;
      case 'share':
        _shareFile(task);
        break;
      case 'lock':
        _lockFile(task);
        break;
      case 'unlock':
        _unlockFile(task);
        break;
      case 'properties':
        _showPropertiesSheet(task);
        break;
      case 'delete':
        _confirmDelete(task);
        break;
    }
  }

  Future<void> _shareFile(DownloadTask task) async {
    final filePath = task.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      _showSnack('File not found on device');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: task.title.isNotEmpty ? task.title : task.fileName,
        ),
      );
    } catch (e) {
      _showSnack('Failed to share file: $e');
    }
  }

  Future<void> _openDownloadedFile(DownloadTask task) async {
    final filePath = task.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      _showSnack('File not found on device');
      return;
    }

    // Check if file is locked
    if (_isTaskLocked(task)) {
      final unlocked = await _authenticateAndUnlock(task);
      if (!unlocked) return;
    }

    final currentPath = task.filePath!;
    final mediaType = _detectMediaType(task.fileName, task.mediaType);

    if (mediaType == 'video') {
      if (!mounted) return;
      VideoPlayerLauncher.smart(source: currentPath, context: context);
    } else if (mediaType == 'audio') {
      final mediaFile = MediaFile(
        id: task.id,
        name: task.fileName,
        path: currentPath,
        displayPath: currentPath,
        type: MediaType.audio,
        size: task.totalBytes,
        dateModified: task.completedAt ?? DateTime.now(),
        dateAdded: task.createdAt,
      );
      AudioPlaybackHelper.playAudio(ref, mediaFile, [mediaFile]);
      _showSnack('Playing in audio player');
    } else if (mediaType == 'document') {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnifiedReaderScreen(
            documentUrl: currentPath,
            title: task.title.isNotEmpty ? task.title : task.fileName,
          ),
        ),
      );
    } else {
      // General file viewer or unified reader
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnifiedReaderScreen(
            documentUrl: currentPath,
            title: task.title.isNotEmpty ? task.title : task.fileName,
          ),
        ),
      );
    }
  }

  bool _isTaskLocked(DownloadTask task) {
    final path = task.filePath ?? task.fileName;
    return path.endsWith('.slock');
  }

  Future<void> _lockFile(DownloadTask task) async {
    final filePath = task.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      _showSnack('File does not exist on disk');
      return;
    }
    if (_isTaskLocked(task)) {
      _showSnack('File is already locked');
      return;
    }

    final hasLock = await SecurityService.instance.hasAppLock();
    if (!mounted) return;

    if (!hasLock) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isSetup: true),
        ),
      );
      if (created != true) return;
    }

    if (!mounted) return;
    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(isSetup: false),
      ),
    );
    if (authenticated != true) return;

    try {
      final newPath = await SecurityService.instance.lockEntityWithSlock(
        File(filePath),
        'LOCKED',
      );

      if (newPath != null) {
        final updatedTask = task.copyWith(
          filePath: newPath,
          fileName: newPath.split(Platform.pathSeparator).last,
        );
        await ref.read(downloadsProvider.notifier).updateTask(updatedTask);
        _showSnack('File encrypted and locked in Vault');
      } else {
        _showSnack('Failed to lock file');
      }
    } catch (e) {
      _showSnack('Lock error: $e');
    }
  }

  Future<bool> _authenticateAndUnlock(DownloadTask task) async {
    final filePath = task.filePath;
    if (filePath == null) return false;

    final lockType = await SecurityService.instance.getFileLockType(filePath);
    if (!mounted) return false;

    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AuthScreen(isSetup: false, initialLockType: lockType),
      ),
    );

    if (authenticated != true) return false;

    try {
      final restoredPath = await SecurityService.instance.unlockEntityWithSlock(
        File(filePath),
      );

      if (restoredPath != null) {
        final updatedTask = task.copyWith(
          filePath: restoredPath,
          fileName: restoredPath.split(Platform.pathSeparator).last,
        );
        await ref.read(downloadsProvider.notifier).updateTask(updatedTask);
        _showSnack('File unlocked');
        return true;
      }
    } catch (e) {
      _showSnack('Unlock error: $e');
    }
    return false;
  }

  Future<void> _unlockFile(DownloadTask task) async {
    await _authenticateAndUnlock(task);
  }

  void _confirmDelete(DownloadTask task) {
    bool deletePhysicalFile = true;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove "${task.title.isNotEmpty ? task.title : task.fileName}"?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Also delete file from storage',
                  style: TextStyle(fontSize: 13),
                ),
                value: deletePhysicalFile,
                onChanged: (val) =>
                    setDialogState(() => deletePhysicalFile = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                ref
                    .read(downloadsProvider.notifier)
                    .deleteDownload(task.id, deleteFile: deletePhysicalFile);
                _showSnack('Download deleted');
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertiesSheet(DownloadTask task) {
    final isLocked = _isTaskLocked(task);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.teal, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Download Properties',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _propertyRow('File Name', task.fileName, canCopy: true),
              _propertyRow(
                'Path',
                task.filePath ?? 'Not yet saved',
                canCopy: task.filePath != null,
              ),
              _propertyRow(
                'Size',
                task.formattedSize != 'Unknown'
                    ? '${task.formattedSize} (${task.totalBytes} bytes)'
                    : 'Unknown',
              ),
              _propertyRow('Source URL', task.url, canCopy: true),
              _propertyRow(
                'Status',
                task.status.name.toUpperCase(),
                highlightColor: task.status == DownloadStatus.completed
                    ? Colors.green
                    : (task.status == DownloadStatus.downloading
                        ? Colors.teal
                        : Colors.orange),
              ),
              _propertyRow(
                'Security',
                isLocked ? 'Locked (.slock AES Encrypted)' : 'Unlocked',
                highlightColor: isLocked ? Colors.amber : Colors.blueGrey,
              ),
              _propertyRow('Added', _formatDateTime(task.createdAt)),
              if (task.completedAt != null)
                _propertyRow('Completed', _formatDateTime(task.completedAt!)),
              if (task.error != null)
                _propertyRow(
                  'Error',
                  task.error!,
                  highlightColor: Colors.redAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertyRow(
    String label,
    String value, {
    bool canCopy = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: highlightColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canCopy)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnack('Copied $label to clipboard');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.copy_rounded, size: 14, color: Colors.teal),
              ),
            ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _detectMediaType(String fileName, String defaultType) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m3u8')) {
      return 'video';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg')) {
      return 'audio';
    }
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.epub') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.mobi')) {
      return 'document';
    }
    if (defaultType.isNotEmpty) return defaultType;
    return 'other';
  }

  IconData _getMediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'document':
        return Icons.menu_book_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getMediaColor(String type) {
    switch (type) {
      case 'video':
        return Colors.teal;
      case 'audio':
        return Colors.deepOrange;
      case 'document':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Downloading Task Item with Live Progress Stream
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadingTaskItem extends ConsumerWidget {
  final DownloadTask task;
  final bool isDark;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onProperties;

  const _DownloadingTaskItem({
    super.key,
    required this.task,
    required this.isDark,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onCancel,
    required this.onDelete,
    required this.onProperties,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(task.id));
    final liveTask = progressAsync.value ?? task;

    final isPaused = liveTask.status == DownloadStatus.paused;
    final isFailed = liveTask.status == DownloadStatus.failed;
    final isDownloading = liveTask.status == DownloadStatus.downloading;

    final mediaType = _detectMediaType(liveTask.fileName, liveTask.mediaType);
    final color = _getMediaColor(mediaType);
    final icon = _getMediaIcon(mediaType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isFailed
              ? Colors.redAccent.withValues(alpha: 0.3)
              : (isPaused
                  ? Colors.orange.withValues(alpha: 0.3)
                  : (isDark
                      ? const Color(0xFF262A34)
                      : Colors.grey.withValues(alpha: 0.15))),
        ),
      ),
      color: isDark ? const Color(0xFF1B1E26) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isFailed
                            ? Colors.redAccent
                            : (isPaused ? Colors.orange : color))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isFailed
                        ? Colors.redAccent
                        : (isPaused ? Colors.orange : color),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveTask.title.isNotEmpty
                            ? liveTask.title
                            : liveTask.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              liveTask.formattedProgress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPaused)
                            const Text(
                              '• PAUSED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            )
                          else if (isFailed)
                            const Text(
                              '• FAILED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Controls
                if (isDownloading)
                  IconButton(
                    tooltip: 'Pause',
                    icon: const Icon(
                      Icons.pause_circle_filled_rounded,
                      color: Colors.orange,
                      size: 26,
                    ),
                    onPressed: onPause,
                  )
                else if (isPaused)
                  IconButton(
                    tooltip: 'Resume',
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.teal,
                      size: 26,
                    ),
                    onPressed: onResume,
                  )
                else if (isFailed)
                  IconButton(
                    tooltip: 'Retry',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.teal,
                      size: 26,
                    ),
                    onPressed: onRetry,
                  ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: onCancel,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            LinearPercentIndicator(
              lineHeight: 6,
              percent: liveTask.progress,
              padding: EdgeInsets.zero,
              barRadius: const Radius.circular(3),
              progressColor: isFailed
                  ? Colors.redAccent
                  : (isPaused ? Colors.orange : Colors.teal),
              backgroundColor: isDark
                  ? const Color(0xFF2B303C)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${liveTask.progressPercent}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                InkWell(
                  onTap: onProperties,
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _detectMediaType(String fileName, String defaultType) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m3u8')) {
      return 'video';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg')) {
      return 'audio';
    }
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.epub') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.mobi')) {
      return 'document';
    }
    if (defaultType.isNotEmpty) return defaultType;
    return 'other';
  }

  static IconData _getMediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'document':
        return Icons.menu_book_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color _getMediaColor(String type) {
    switch (type) {
      case 'video':
        return Colors.teal;
      case 'audio':
        return Colors.deepOrange;
      case 'document':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }
}

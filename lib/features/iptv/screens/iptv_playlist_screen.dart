import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../helpers/responsive_helper.dart';
import '../models/iptv_models.dart';
import '../providers/iptv_providers.dart';
import '../widgets/iptv_channel_card.dart';

/// Shows a single playlist's channels in a YouTube-style layout:
/// category chips + responsive grid/list + search.
class IptvPlaylistScreen extends ConsumerStatefulWidget {
  const IptvPlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<IptvPlaylistScreen> createState() => _IptvPlaylistScreenState();
}

class _IptvPlaylistScreenState extends ConsumerState<IptvPlaylistScreen> {
  final _searchController = TextEditingController();
  bool _gridView = true;
  bool _showFavoritesOnly = false;
  String _languageFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playChannel(int index) async {
    final channels = ref
        .read(iptvChannelsProvider(widget.playlistId))
        .visibleChannels;
    if (channels.isEmpty || index >= channels.length) return;
    await IptvPlaybackHelper.play(
      ref,
      channels: channels,
      index: index,
      context: context,
    );
  }

  void _onSearch(String query) {
    ref.read(iptvChannelsProvider(widget.playlistId).notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final channelsState = ref.watch(iptvChannelsProvider(widget.playlistId));
    final playlistAsync = ref.watch(iptvPlaylistsProvider);

    final playlist = playlistAsync.isEmpty
        ? null
        : playlistAsync.where((p) => p.id == widget.playlistId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              playlist?.name ?? 'Channels',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (playlist != null)
              Text(
                '${playlist.channelCount} channels · ${playlist.sourceLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Theme.of(context).colorScheme.error : null,
            ),
            tooltip: 'Favorites',
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(iptvPlaylistsProvider.notifier).refreshPlaylist(
                    widget.playlistId,
                  );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search channels',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          );
                  },
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context, channelsState),
    );
  }

  Widget _buildBody(BuildContext context, IptvChannelsState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) {
      return const _LoadingGrid();
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref
                  .read(iptvChannelsProvider(widget.playlistId).notifier)
                  .refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv, size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No channels found'),
            const SizedBox(height: 8),
            Text(
              'Try refreshing the playlist or add another source.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    var visible = _showFavoritesOnly
        ? state.visibleChannels.where((c) => c.isFavorite).toList()
        : state.visibleChannels;

    if (_languageFilter.isNotEmpty) {
      visible =
          visible.where((c) => c.language == _languageFilter).toList();
    }

    final distinctLanguages = <String>{};
    for (final c in state.channels) {
      final lang = c.language?.trim();
      if (lang != null && lang.isNotEmpty) distinctLanguages.add(lang);
    }
    final showLanguageFilter = distinctLanguages.length > 1;

    if (visible.isEmpty) {
      return Center(
        child: Text(
          _showFavoritesOnly ? 'No favorite channels yet' : 'No results',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        _CategoryChips(
          groups: state.groups,
          selectedGroup: state.selectedGroup,
          onSelected: (g) =>
              ref.read(iptvChannelsProvider(widget.playlistId).notifier).selectGroup(g),
        ),
        if (showLanguageFilter)
          _LanguageChips(
            languages: distinctLanguages.toList()..sort(),
            selected: _languageFilter,
            onSelected: (lang) => setState(() {
              _languageFilter = lang;
              if (lang.isNotEmpty) _showFavoritesOnly = false;
            }),
          ),
        Expanded(
          child: _gridView
              ? _ChannelGrid(
                  channels: visible,
                  onTap: (i) => _playChannel(i),
                  onToggleFavorite: _toggleFavorite,
                )
              : _ChannelList(
                  channels: visible,
                  onTap: (i) => _playChannel(i),
                  onToggleFavorite: _toggleFavorite,
                ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(int index) async {
    final channels = ref
        .read(iptvChannelsProvider(widget.playlistId))
        .visibleChannels;
    if (index >= channels.length) return;
    await ref
        .read(iptvChannelsProvider(widget.playlistId).notifier)
        .toggleFavorite(channels[index].id);
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final all = ['All', ...groups];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final group = all[index];
          final selected = (index == 0 && selectedGroup.isEmpty) ||
              (index > 0 && group == selectedGroup);
          return ChoiceChip(
            label: Text(
              index == 0 ? 'All' : group,
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected,
            onSelected: (_) => onSelected(index == 0 ? '' : group),
            visualDensity: VisualDensity.compact,
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
          );
        },
      ),
    );
  }
}

class _LanguageChips extends StatelessWidget {
  const _LanguageChips({
    required this.languages,
    required this.selected,
    required this.onSelected,
  });

  final List<String> languages;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final all = ['All languages', ...languages];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final selectedChip = isAll ? selected.isEmpty : all[index] == selected;
          return ChoiceChip(
            label: Text(
              isAll ? 'All languages' : all[index],
              style: const TextStyle(fontSize: 12),
            ),
            avatar: isAll
                ? const Icon(Icons.language, size: 14)
                : null,
            selected: selectedChip,
            onSelected: (_) => onSelected(isAll ? '' : all[index]),
            visualDensity: VisualDensity.compact,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
          );
        },
      ),
    );
  }
}

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.channels,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final List<IptvChannel> channels;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return IptvChannelCard(
          key: ValueKey(channel.id),
          channel: channel,
          grid: true,
          onTap: () => onTap(index),
          onToggleFavorite: () => onToggleFavorite(index),
        );
      },
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final List<IptvChannel> channels;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: IptvChannelCard(
            key: ValueKey(channel.id),
            channel: channel,
            grid: false,
            onTap: () => onTap(index),
            onToggleFavorite: () => onToggleFavorite(index),
          ),
        );
      },
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
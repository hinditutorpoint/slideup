import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/iptv_models.dart';
import '../services/iptv_database_service.dart';
import '../widgets/iptv_player.dart';

enum _PanelTab { channels, favorites, watching }

/// Professional split IPTV player screen.
///
/// Top section: a full-bleed live player with auto-hiding overlay controls.
/// Bottom section: a collapsible, rounded channel panel with tabs
/// (Channels / Favorites / My Watching), search, category & language filter
/// chips, a live equalizer on the playing channel and tap-to-switch. Supports
/// immersive landscape fullscreen, channel up/down (buttons + swipe on video).
class IptvPlayerScreen extends StatefulWidget {
  const IptvPlayerScreen({
    super.key,
    required this.channels,
    required this.playlistName,
    this.startIndex = 0,
  });

  final List<IptvChannel> channels;
  final String playlistName;
  final int startIndex;

  @override
  State<IptvPlayerScreen> createState() => _IptvPlayerScreenState();
}

class _IptvPlayerScreenState extends State<IptvPlayerScreen> {
  late int _index;
  late final List<_ChannelGroup> _channelGroups;
  final Map<String, int> _selectedVariant = {};
  bool _fullscreen = false;
  bool _listVisible = true;
  bool _searchOpen = false;
  _PanelTab _tab = _PanelTab.channels;
  String _selectedGroup = '';
  String _selectedLanguage = '';
  late final Set<String> _favoriteIds;
  final List<String> _recentNames = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _currentTileKey = GlobalKey();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _channelGroups = _buildChannelGroups(widget.channels);
    _index = _channelGroups.isEmpty
        ? 0
        : widget.startIndex.clamp(0, _channelGroups.length - 1);
    _favoriteIds = widget.channels
        .where((c) => c.isFavorite)
        .map((c) => c.id)
        .toSet();
    _recentNames.add(_group.baseName);
  }

  _ChannelGroup get _group => _channelGroups[_index];

  IptvChannel get _current {
    final g = _group;
    final i = _selectedVariant[g.baseName] ?? 0;
    return g.variants[i];
  }

  List<String> get _groups {
    final set = <String>{};
    for (final g in _channelGroups) {
      final cat = g.group.trim();
      if (cat.isNotEmpty) set.add(cat);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _languages {
    final set = <String>{};
    for (final g in _channelGroups) {
      final l = g.language?.trim();
      if (l != null && l.isNotEmpty) set.add(l);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<_ChannelGroup> get _visibleGroups {
    Iterable<_ChannelGroup> list = switch (_tab) {
      _PanelTab.favorites => _channelGroups.where(
        (g) => g.variants.any((c) => _favoriteIds.contains(c.id)),
      ),
      _PanelTab.watching => [
        for (final name in _recentNames)
          for (final g in _channelGroups)
            if (g.baseName == name) g,
      ],
      _PanelTab.channels => _channelGroups,
    };

    if (_selectedGroup.isNotEmpty) {
      list = list.where((g) => g.group == _selectedGroup);
    }
    if (_selectedLanguage.isNotEmpty) {
      list = list.where((g) => (g.language?.trim() ?? '') == _selectedLanguage);
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where(
        (g) =>
            g.baseName.toLowerCase().contains(q) ||
            g.group.toLowerCase().contains(q),
      );
    }
    return list.toList();
  }

  void _switchTo(int i) {
    if (i < 0 || i >= _channelGroups.length) return;
    setState(() {
      _index = i;
      final name = _channelGroups[i].baseName;
      _recentNames
        ..remove(name)
        ..insert(0, name);
      if (_recentNames.length > 50) {
        _recentNames.removeRange(50, _recentNames.length);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentTileKey.currentContext;
      if (ctx != null && _listVisible) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
        );
      }
    });
  }

  void _selectVariant(int variantIndex) {
    final g = _group;
    if (variantIndex < 0 || variantIndex >= g.variants.length) return;
    setState(() => _selectedVariant[g.baseName] = variantIndex);
  }

  void _toggleFavoriteGroup(_ChannelGroup g) {
    final isFav = g.variants.any((c) => _favoriteIds.contains(c.id));
    setState(() {
      for (final c in g.variants) {
        if (isFav) {
          _favoriteIds.remove(c.id);
        } else {
          _favoriteIds.add(c.id);
        }
      }
    });
    final db = IptvDatabaseService.instance;
    for (final c in g.variants) {
      final wanted = !isFav;
      if (c.isFavorite != wanted) db.toggleFavoriteChannel(c.id);
    }
  }

  void _channelUp() => _switchTo(_index - 1);

  void _channelDown() => _switchTo(_index + 1);

  void _toggleList() {
    setState(() => _listVisible = !_listVisible);
    if (_listVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _currentTileKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.3,
          );
        }
      });
    }
  }

  Future<void> _enterFullscreen() async {
    setState(() => _fullscreen = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    setState(() => _fullscreen = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _handleBack() {
    if (_fullscreen) {
      _exitFullscreen();
    } else if (_searchOpen) {
      setState(() {
        _searchOpen = false;
        _searchCtrl.clear();
        _query = '';
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Scaffold(body: Center(child: Text('No channels')));
    }

    final current = _current;
    final group = _group;
    final playerArea = IptvPlayer(
      key: ValueKey(group.baseName),
      channel: current,
      onBack: _handleBack,
      onToggleList: _toggleList,
      onToggleFullscreen: _fullscreen ? _exitFullscreen : _enterFullscreen,
      onChannelUp: _channelUp,
      onChannelDown: _channelDown,
      qualities: group.variants.map(_qualityLabel).toList(),
      currentQualityIndex: _selectedVariant[group.baseName] ?? 0,
      onQualitySelected: _selectVariant,
    );

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _fullscreen
            ? playerArea
            : Column(
                children: [
                  Expanded(child: playerArea),
                  if (_listVisible) _buildChannelPanel(context),
                ],
              ),
      ),
    );
  }

  Widget _buildChannelPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = _visibleGroups;
    final groups = _groups;
    final languages = _languages;
    final showLangFilter = languages.length > 1;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
            child: Row(
              children: [
                Text(
                  switch (_tab) {
                    _PanelTab.channels => 'Channels',
                    _PanelTab.favorites => 'Favorites',
                    _PanelTab.watching => 'My Watching',
                  },
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(
                    _searchOpen ? Icons.close : Icons.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchCtrl.clear();
                      _query = '';
                    }
                  }),
                ),
              ],
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search channels…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          if (!_searchOpen && _tab == _PanelTab.channels && groups.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final isAll = i == 0;
                  final group = isAll ? '' : groups[i - 1];
                  final selected = group == _selectedGroup;
                  return ChoiceChip(
                    label: Text(
                      isAll ? 'All' : group,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGroup = group),
                    visualDensity: VisualDensity.compact,
                    selectedColor: colorScheme.primaryContainer,
                  );
                },
              ),
            ),
          if (!_searchOpen && showLangFilter && groups.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: languages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final isAll = i == 0;
                  final lang = isAll ? '' : languages[i - 1];
                  final selected = lang == _selectedLanguage;
                  return ChoiceChip(
                    avatar: isAll ? const Icon(Icons.language, size: 13) : null,
                    label: Text(
                      isAll ? 'All languages' : lang,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedLanguage = lang),
                    visualDensity: VisualDensity.compact,
                    selectedColor: colorScheme.secondaryContainer,
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(switch (_tab) {
                      _PanelTab.favorites => 'No favorite channels yet',
                      _PanelTab.watching =>
                        'Nothing watched yet — start playing',
                      _PanelTab.channels => 'No channels found',
                    }, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final globalIndex = _channelGroups.indexOf(entry);
                      final selected = globalIndex == _index;
                      final selectedVariant =
                          _selectedVariant[entry.baseName] ?? 0;
                      return _ChannelTile(
                        key: selected ? _currentTileKey : null,
                        channel: entry.variants[selectedVariant],
                        displayName: entry.baseName,
                        variantCount: entry.variants.length,
                        selected: selected,
                        isFavorite: entry.variants.any(
                          (c) => _favoriteIds.contains(c.id),
                        ),
                        onToggleFavorite: () => _toggleFavoriteGroup(entry),
                        onTap: () => _switchTo(globalIndex),
                      );
                    },
                  ),
          ),
          _CurvedTabBar(
            index: _tab.index,
            onTap: (i) => setState(() {
              _tab = _PanelTab.values[i];
              _searchOpen = false;
              _searchCtrl.clear();
              _query = '';
              _selectedGroup = '';
              _selectedLanguage = '';
            }),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    super.key,
    required this.channel,
    required this.displayName,
    required this.variantCount,
    required this.selected,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final IptvChannel channel;
  final String displayName;
  final int variantCount;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: _ChannelLogo(channel: channel),
        title: Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: channel.group.isEmpty
            ? null
            : Text(
                channel.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFavorite
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
              onPressed: onToggleFavorite,
            ),
            if (selected)
              _PlayingIndicator(color: colorScheme.primary)
            else
              Icon(
                Icons.play_circle_outline,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});

  final IptvChannel channel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logo = channel.logo;
    final fallback = Container(
      width: 52,
      height: 34,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        channel.audioOnly ? Icons.radio : Icons.live_tv,
        size: 18,
        color: colorScheme.onSecondaryContainer,
      ),
    );
    if (logo == null || logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 52,
        height: 34,
        child: Image.network(
          logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator({required this.color});

  final Color color;

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 16.0;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.5 + 0.5 * math.sin(t * 2 * math.pi)),
              _bar(0.5 + 0.5 * math.sin(t * 2 * math.pi + 2.1)),
              _bar(0.5 + 0.5 * math.sin(t * 2 * math.pi + 4.2)),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double raw) {
    final h = raw.clamp(0.25, 1.0);
    return Container(
      width: 3,
      height: 16 * h,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// A group of channels sharing the same base name, differing only in quality
/// (e.g. "B4U Music (576P)" and "B4U Music (720P)").
class _ChannelGroup {
  _ChannelGroup({
    required this.baseName,
    required this.group,
    required this.language,
    required this.logo,
    required this.variants,
  });

  final String baseName;
  final String group;
  final String? language;
  final String? logo;
  final List<IptvChannel> variants;
}

List<_ChannelGroup> _buildChannelGroups(List<IptvChannel> channels) {
  final byBase = <String, List<IptvChannel>>{};
  for (final c in channels) {
    byBase.putIfAbsent(_baseName(c.name), () => []).add(c);
  }
  return [
    for (final e in byBase.entries)
      _ChannelGroup(
        baseName: e.key,
        group: e.value.first.group,
        language: e.value.first.language,
        logo: e.value.first.logo,
        variants: List.of(e.value)
          ..sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a))),
      ),
  ];
}

/// Strips a trailing quality marker like " (576P)", " 720p" or " HD".
String _baseName(String name) {
  return name
      .replaceFirst(
        RegExp(r'[-\s]*\(?(\d{3,4}\s*[pPiK])\)?\s*$', caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'[-\s]*(HD|FHD|SD|4K|UHD)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

/// Resolution (e.g. 720 for "720P") used to sort variants, best first.
int _qualityRank(IptvChannel c) {
  final m = RegExp(
    r'(\d{3,4})\s*[pPiK]',
    caseSensitive: false,
  ).firstMatch(c.name);
  return m == null ? 0 : int.parse(m.group(1)!);
}

/// Human label for a variant, e.g. "576P", falling back to "Auto".
String _qualityLabel(IptvChannel c) {
  final m = RegExp(
    r'\(?(\d{3,4})\s*[pPiK]?\)?',
    caseSensitive: false,
  ).firstMatch(c.name);
  return m == null ? 'Auto' : m.group(1)!.toUpperCase();
}

/// Curved bottom tab bar with labels, styled to match the home screen's
/// `CurvedNavigationBar` (primary circular button, transparent background).
class _CurvedTabBar extends StatelessWidget {
  const _CurvedTabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _tabs = [
    (
      icon: Icons.live_tv_outlined,
      selectedIcon: Icons.live_tv,
      label: 'Channels',
    ),
    (
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      label: 'Favorites',
    ),
    (
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'Watching',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 32,
                        decoration: BoxDecoration(
                          color: i == index
                              ? colorScheme.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          i == index ? _tabs[i].selectedIcon : _tabs[i].icon,
                          size: 22,
                          color: i == index
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tabs[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: i == index
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
    final entries = _visibleGroups;
    final groups = _groups;
    final languages = _languages;
    final showLangFilter = languages.length > 1;

    // Premium dark TV panel colours
    const panelBg = Color(0xFF0D0D14);
    const panelSurface = Color(0xFF13131F);
    const accent = Color(0xFF6C63FF);
    const accentGlow = Color(0x406C63FF);
    const dividerColor = Color(0xFF1E1E2E);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      decoration: const BoxDecoration(
        color: panelBg,
        border: Border(
          top: BorderSide(color: Color(0xFF1E1E2E), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            decoration: const BoxDecoration(
              color: panelSurface,
              border: Border(
                bottom: BorderSide(color: dividerColor),
              ),
            ),
            child: Row(
              children: [
                // Coloured accent bar
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [BoxShadow(color: accentGlow, blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  switch (_tab) {
                    _PanelTab.channels  => 'Channels',
                    _PanelTab.favorites => 'Favourites',
                    _PanelTab.watching  => 'Recently Watched',
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Search toggle
                _TvIconButton(
                  icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  onTap: () => setState(() {
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

          // ── Search bar ────────────────────────────────────────────────────
          if (_searchOpen)
            Container(
              color: panelSurface,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: accent,
                decoration: InputDecoration(
                  hintText: 'Search channels…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: accent),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2B),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2A2A3F)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2A2A3F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: accent),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

          // ── Category filter chips ─────────────────────────────────────────
          if (!_searchOpen && _tab == _PanelTab.channels && groups.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final isAll = i == 0;
                  final grp   = isAll ? '' : groups[i - 1];
                  final selected = grp == _selectedGroup;
                  return _TvFilterChip(
                    label: isAll ? 'All' : grp,
                    selected: selected,
                    onTap: () => setState(() => _selectedGroup = grp),
                    accent: accent,
                  );
                },
              ),
            ),

          // ── Language filter chips ─────────────────────────────────────────
          if (!_searchOpen && showLangFilter && groups.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                scrollDirection: Axis.horizontal,
                itemCount: languages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final isAll = i == 0;
                  final lang  = isAll ? '' : languages[i - 1];
                  final selected = lang == _selectedLanguage;
                  return _TvFilterChip(
                    label: isAll ? '🌐  All' : lang,
                    selected: selected,
                    onTap: () => setState(() => _selectedLanguage = lang),
                    accent: const Color(0xFF00C9A7),
                  );
                },
              ),
            ),

          const SizedBox(height: 1),

          // ── Channel list ─────────────────────────────────────────────────
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          switch (_tab) {
                            _PanelTab.favorites => Icons.favorite_border_rounded,
                            _PanelTab.watching  => Icons.history_rounded,
                            _PanelTab.channels  => Icons.search_off_rounded,
                          },
                          size: 40,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          switch (_tab) {
                            _PanelTab.favorites => 'No favourite channels yet',
                            _PanelTab.watching  => 'Nothing watched yet',
                            _PanelTab.channels  => 'No channels found',
                          },
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry       = entries[i];
                      final globalIndex = _channelGroups.indexOf(entry);
                      final selected    = globalIndex == _index;
                      final selVariant  = _selectedVariant[entry.baseName] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ChannelTile(
                          key: selected ? _currentTileKey : null,
                          channel: entry.variants[selVariant],
                          displayName: entry.baseName,
                          variantCount: entry.variants.length,
                          selected: selected,
                          isFavorite: entry.variants.any(
                            (c) => _favoriteIds.contains(c.id),
                          ),
                          onToggleFavorite: () => _toggleFavoriteGroup(entry),
                          onTap: () => _switchTo(globalIndex),
                        ),
                      );
                    },
                  ),
          ),

          // ── Bottom tab bar ────────────────────────────────────────────────
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

// ─── Premium TV Filter Chip ────────────────────────────────────────────────────
class _TvFilterChip extends StatelessWidget {
  const _TvFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : const Color(0xFF1A1A2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : const Color(0xFF2A2A3F),
            width: selected ? 1.2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white54,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─── Small TV Icon Button ──────────────────────────────────────────────────────
class _TvIconButton extends StatelessWidget {
  const _TvIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A3F)),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}

// ─── Premium Channel Tile ──────────────────────────────────────────────────────
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

  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x406C63FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1730) : const Color(0xFF131320),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : const Color(0xFF1F1F32),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: _accentGlow,
                    blurRadius: 14,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              // Left accent strip for selected
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: const BoxDecoration(
                      color: _accent,
                      boxShadow: [BoxShadow(color: _accentGlow, blurRadius: 6)],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: selected ? 14 : 10,
                  right: 6,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    // Channel logo
                    _ChannelLogo(channel: channel, selected: selected),
                    const SizedBox(width: 10),

                    // Channel info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // LIVE badge
                              if (selected) ...[
                                _LiveBadge(),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.white70,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (channel.group.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              channel.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? _accent.withValues(alpha: 0.8)
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Trailing: favourite + playing indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onToggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isFavorite),
                                size: 17,
                                color: isFavorite
                                    ? const Color(0xFFEF4444)
                                    : Colors.white30,
                              ),
                            ),
                          ),
                        ),
                        if (selected)
                          _PlayingIndicator(color: _accent)
                        else
                          const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 18,
                              color: Colors.white24,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulsing LIVE Badge ────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (_, __) => Opacity(
        opacity: _fade.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Color(0x60EF4444), blurRadius: 6),
            ],
          ),
          child: const Text(
            '⬤  LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel, this.selected = false});

  final IptvChannel channel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C63FF);
    final logo = channel.logo;

    final fallback = Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? [const Color(0xFF2A2560), const Color(0xFF1A1730)]
              : [const Color(0xFF1E1E30), const Color(0xFF131320)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.5) : const Color(0xFF2A2A3F),
        ),
      ),
      child: Icon(
        channel.audioOnly ? Icons.radio_rounded : Icons.live_tv_rounded,
        size: 18,
        color: selected ? accent : Colors.white30,
      ),
    );

    if (logo == null || logo.isEmpty) return fallback;

    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? accent : const Color(0xFF2A2A3F),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [const BoxShadow(color: Color(0x406C63FF), blurRadius: 8)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        logo,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
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

/// Premium dark TV-style bottom tab bar
class _CurvedTabBar extends StatelessWidget {
  const _CurvedTabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _accent = Color(0xFF6C63FF);

  static const _tabs = [
    (icon: Icons.live_tv_outlined,   selectedIcon: Icons.live_tv_rounded,    label: 'Channels'),
    (icon: Icons.favorite_outline,   selectedIcon: Icons.favorite_rounded,   label: 'Favourites'),
    (icon: Icons.history_outlined,   selectedIcon: Icons.history_rounded,    label: 'Watching'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D14),
          border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 46,
                        height: 30,
                        decoration: BoxDecoration(
                          color: i == index
                              ? _accent.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: i == index
                              ? Border.all(color: _accent.withValues(alpha: 0.4))
                              : null,
                          boxShadow: i == index
                              ? [const BoxShadow(color: Color(0x306C63FF), blurRadius: 10)]
                              : null,
                        ),
                        child: Icon(
                          i == index ? _tabs[i].selectedIcon : _tabs[i].icon,
                          size: 19,
                          color: i == index ? _accent : Colors.white30,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                          color: i == index ? _accent : Colors.white30,
                          letterSpacing: 0.3,
                        ),
                        child: Text(_tabs[i].label),
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

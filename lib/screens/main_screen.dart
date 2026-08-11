import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'recent_files_screen.dart';
import 'videos_screen.dart';
import 'audios_screen.dart';
import 'documents_screen.dart';
import 'file_browser_screen.dart';
import 'settings_screen.dart';
import 'playlists_screen.dart';
import 'extracted_files_screen.dart';
import 'favorites_screen.dart';
import 'about_screen.dart';
import '../services/security_service.dart';
import 'auth_screen.dart';
import 'image_gallery_screen.dart';
import '../widgets/play_url_dialog.dart';
import '../widgets/theme_selector_widget.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import '../models/media_file.dart';
import '../models/disk_info.dart';
import '../features/features_navigation_screen.dart';
import '../features/video_search/screens/video_search_screen.dart';
import '../features/video_player/providers/video_player_provider.dart';
import '../providers/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/documents/screens/unified_reader_screen.dart';
import '../features/video_editor/video_editor_screen.dart';

// Quick action model
class QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _fabAnimationController;
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final List<_NavDestination> _destinations = const [
    _NavDestination(
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled,
      label: 'Recent',
      tooltip: 'Recently played files',
    ),
    _NavDestination(
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
      label: 'Videos',
      tooltip: 'Video library',
    ),
    _NavDestination(
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
      label: 'Music',
      tooltip: 'Music library',
    ),
    _NavDestination(
      icon: Icons.article_outlined,
      selectedIcon: Icons.article,
      label: 'Docs',
      tooltip: 'Documents',
    ),
    _NavDestination(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Files',
      tooltip: 'File browser',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAuthentication();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    final hasPassword = await SecurityService.instance.hasAppPassword();

    if (hasPassword && mounted) {
      final canUseBiometric = await SecurityService.instance.canUseBiometric();
      final biometricEnabled = await SecurityService.instance
          .isBiometricEnabled();

      bool authenticated = false;

      if (canUseBiometric && biometricEnabled) {
        authenticated = await SecurityService.instance
            .authenticateWithBiometric();
      }

      if (!authenticated && mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthScreen(isSetup: false),
            fullscreenDialog: true,
          ),
        );

        if (result != true && mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLargeScreen = MediaQuery.sizeOf(context).width >= 600;

    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: colorScheme.surface,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _exitApp();
      },
      child: isLargeScreen
          ? _buildLargeScreenLayout(theme, colorScheme)
          : _buildMobileLayout(theme, colorScheme),
    );
  }

  /// Stop all playback and fully close the app when back is pressed on home.
  Future<void> _exitApp() async {
    try {
      await AudioPlaybackHelper.stopAudio(ref);
    } catch (e) {
      debugPrint('⚠️ Stop audio on exit error: $e');
    }

    try {
      final videoNotifier = ref.read(videoPlayerProvider.notifier);
      if (!videoNotifier.isDisposed) {
        await videoNotifier.stop();
      }
    } catch (e) {
      debugPrint('⚠️ Stop video on exit error: $e');
    }

    if (mounted) {
      SystemNavigator.pop();
    }
  }

  // ==================== MOBILE LAYOUT ====================

  Widget _buildMobileLayout(ThemeData theme, ColorScheme colorScheme) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(theme, colorScheme),
      drawer: _buildDrawer(theme, colorScheme),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(colorScheme),
      floatingActionButton: _buildFAB(colorScheme),
    );
  }

  // ==================== LARGE SCREEN LAYOUT ====================

  Widget _buildLargeScreenLayout(ThemeData theme, ColorScheme colorScheme) {
    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: _buildRailHeader(colorScheme),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.movie_edit),
                        onPressed: _openVideoEditor,
                        tooltip: 'Video Editor',
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => _navigateTo(const SettingsScreen()),
                        tooltip: 'Settings',
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: _showAboutDialog,
                        tooltip: 'About',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: _destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Tooltip(message: d.tooltip, child: Icon(d.icon)),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildLargeScreenAppBar(theme, colorScheme),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(colorScheme),
    );
  }

  Widget _buildRailHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.play_circle, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          FloatingActionButton.small(
            heroTag: 'nav_fab',
            onPressed: _showQuickActions,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeScreenAppBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            _destinations[_selectedIndex].label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildSearchField(colorScheme, width: 300),
          const SizedBox(width: 16),
          _buildQuickActionsRow(colorScheme),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: _isSearchExpanded
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _collapseSearch,
            )
          : IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
      title: _isSearchExpanded
          ? _buildSearchField(colorScheme)
          : Text(
              _destinations[_selectedIndex].label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
      actions: _isSearchExpanded
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _expandSearch,
                tooltip: 'Search',
              ),
              _buildNotificationBadge(colorScheme),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sort',
                    child: ListTile(
                      leading: Icon(Icons.sort),
                      title: Text('Sort by'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.grid_view),
                      title: Text('View mode'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Refresh'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme, {double? width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: _isSearchExpanded,
        decoration: InputDecoration(
          hintText: 'Search files...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          isDense: true,
        ),
        onChanged: (value) => setState(() {}),
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildNotificationBadge(ColorScheme colorScheme) {
    return Badge(
      isLabelVisible: true,
      label: const Text('3'),
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: _showNotifications,
        tooltip: 'Notifications',
      ),
    );
  }

  Widget _buildQuickActionsRow(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuickActionButton(
          icon: Icons.add_link_rounded,
          label: 'URL',
          color: colorScheme.primary,
          onTap: _playWithUrl,
        ),
        const SizedBox(width: 8),
        _buildQuickActionButton(
          icon: Icons.book_outlined,
          label: 'Books',
          color: colorScheme.tertiary,
          onTap: () => _navigateTo(const FeaturesNavigationScreen()),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BOTTOM NAV ====================

  Widget _buildBottomNav(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        animationDuration: const Duration(milliseconds: 400),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
                tooltip: d.tooltip,
              ),
            )
            .toList(),
      ),
    );
  }

  // ==================== FAB ====================

  Widget _buildFAB(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      heroTag: 'main_fab',
      onPressed: _showQuickActions,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Quick Actions'),
    );
  }

  // ==================== DRAWER ====================

  Widget _buildDrawer(ThemeData theme, ColorScheme colorScheme) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(theme, colorScheme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerSection(
                  title: 'Library',
                  children: [
                    _DrawerItem(
                      icon: Icons.playlist_play_rounded,
                      title: 'Playlists',
                      subtitle: '12 playlists',
                      onTap: () => _navigateTo(const PlaylistsScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.photo_library_rounded,
                      title: 'Images',
                      subtitle: 'Photo gallery',
                      onTap: () => _navigateTo(const ImageGalleryScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.video_collection_sharp,
                      title: 'Videos',
                      subtitle: 'Video Archive',
                      onTap: () => _navigateTo(const VideoSearchScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.auto_stories_rounded,
                      title: 'Books Archive',
                      subtitle: 'Search & read PDFs',
                      badge: 'NEW',
                      badgeColor: colorScheme.tertiary,
                      onTap: () =>
                          _navigateTo(const FeaturesNavigationScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.favorite_rounded,
                      title: 'Favorites',
                      subtitle: '24 items',
                      onTap: () => _navigateTo(const FavoritesScreen()),
                    ),
                  ],
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildDrawerSection(
                  title: 'Tools',
                  children: [
                    _DrawerItem(
                      icon: Icons.link_rounded,
                      title: 'Play from URL',
                      subtitle: 'Stream online media',
                      onTap: _playWithUrl,
                    ),
                    _DrawerItem(
                      icon: Icons.file_download_rounded,
                      title: 'Extracted Files',
                      subtitle: 'Converted & extracted',
                      onTap: () => _navigateTo(const ExtractedFilesScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Watch History',
                      subtitle: 'Recently watched',
                      onTap: () {},
                    ),
                    _DrawerItem(
                      icon: Icons.movie_edit,
                      title: 'Video Editor',
                      subtitle: 'Trim, effects & export',
                      onTap: _openVideoEditor,
                    ),
                  ],
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildDrawerSection(
                  title: 'Settings',
                  children: [
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'App preferences',
                      onTap: () => _navigateTo(const SettingsScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.color_lens_rounded,
                      title: 'Theme',
                      subtitle: 'Appearance settings',
                      trailing: _buildThemeToggle(colorScheme),
                      onTap: () {},
                    ),
                    _DrawerItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version 1.0.0',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildDrawerFooter(colorScheme),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 24,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Logo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.play_circle_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Slideup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Text(
            'Media Player',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Storage indicator
          _buildStorageIndicator(),
        ],
      ),
    );
  }

  Widget _buildStorageIndicator() {
    return FutureBuilder<DiskInfo>(
      future: getStorageInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 40, child: LinearProgressIndicator());
        }

        final storage = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Storage',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${storage.usedGB.toStringAsFixed(1)} GB / ${storage.totalGB.toStringAsFixed(0)} GB',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: storage.usedFraction.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 1,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildThemeToggle(ColorScheme colorScheme) {
    return Consumer(
      builder: (context, ref, child) {
        final themeAsync = ref.watch(themeProvider);

        return themeAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const Icon(Icons.error_outline),
          data: (themeState) {
            final colors = AppTheme.getThemeColors(themeState.themeMode);

            return GestureDetector(
              onTap: () => _showThemeSelector(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.2),
                      colors.secondary.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        themeState.themeMode.icon,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      themeState.themeMode.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.palette_rounded),
                    const SizedBox(width: 12),
                    Text(
                      'App Theme',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const ThemeSelector(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Guest User',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Free Version',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {},
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }

  // ==================== BODY ====================

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: IndexedStack(
        key: ValueKey(_selectedIndex),
        index: _selectedIndex,
        children: const [
          RecentFilesScreen(),
          VideosScreen(),
          AudiosScreen(),
          DocumentsScreen(),
          FileBrowserScreen(),
        ],
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  void _showQuickActions() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.flash_on_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Choose an action to get started',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Actions grid
              Expanded(
                child: GridView.count(
                  controller: scrollController,
                  crossAxisCount: 3,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                  children: [
                    _buildQuickActionCard(
                      icon: Icons.add_link_rounded,
                      label: 'Play URL',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _playWithUrl();
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.auto_stories_rounded,
                      label: 'Books',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _navigateTo(const FeaturesNavigationScreen());
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.playlist_add_rounded,
                      label: 'New Playlist',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        // Create playlist
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.folder_open_rounded,
                      label: 'Open File',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _openFilePicker();
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.pink,
                      onTap: () {
                        Navigator.pop(context);
                        _navigateTo(const ImageGalleryScreen());
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        // Scan QR code
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.movie_edit,
                      label: 'Video Editor',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        _openVideoEditor();
                      },
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  void _onDestinationSelected(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = index);
    }
  }

  void _expandSearch() {
    setState(() => _isSearchExpanded = true);
    _searchFocusNode.requestFocus();
  }

  void _collapseSearch() {
    setState(() {
      _isSearchExpanded = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    // Implement search
    _collapseSearch();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'sort':
        _showSortOptions();
        break;
      case 'view':
        _toggleViewMode();
        break;
      case 'refresh':
        // Refresh current screen
        break;
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...[
              ('Name', Icons.sort_by_alpha),
              ('Date Modified', Icons.schedule),
              ('Size', Icons.data_usage),
              ('Type', Icons.category),
            ].map(
              (item) => ListTile(
                leading: Icon(item.$2),
                title: Text(item.$1),
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _toggleViewMode() {
    // Toggle between grid and list view
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No new notifications'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context); // Close drawer
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _playWithUrl() async {
    Navigator.pop(context); // Close drawer if open

    final result = await showDialog<MediaFile>(
      context: context,
      builder: (_) => const PlayUrlDialog(),
    );

    if (result != null && mounted) {
      final playlist = [result];

      if (result.type == MediaType.video) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerLauncher.screen(
              file: result,
              files: playlist,
              index: 0,
            ),
          ),
        );
      } else if (result.type == MediaType.audio) {
        AudioPlaybackHelper.playAudio(ref, result, playlist);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unsupported media type'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openFilePicker() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final selectedFiles = result.files;
      final firstPath = selectedFiles.first.path;
      if (firstPath == null) return;

      final directory = Directory(path.dirname(firstPath));
      if (!await directory.exists()) return;

      final allFiles = await directory.list().toList();
      if (!mounted) return;

      final mediaFiles = <MediaFile>[];
      for (final entity in allFiles) {
        if (entity is File) {
          final mediaFile = MediaFile.fromFile(entity);
          if (mediaFile != null) {
            mediaFiles.add(mediaFile);
          }
        }
      }

      if (mediaFiles.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'No supported files found in selected location',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final selectedFile = mediaFiles.firstWhere(
        (f) => selectedFiles.any((sf) => sf.path == f.path),
        orElse: () => mediaFiles.first,
      );

      final videoFiles = mediaFiles
          .where((f) => f.type == MediaType.video)
          .toList();
      final audioFiles = mediaFiles
          .where((f) => f.type == MediaType.audio)
          .toList();
      final documentFiles = mediaFiles
          .where((f) => f.type == MediaType.document)
          .toList();

      if (!mounted) return;

      // ---------- UI ACTIONS (SYNC ONLY) ----------

      if (videoFiles.isNotEmpty &&
          audioFiles.isEmpty &&
          documentFiles.isEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerLauncher.screen(
              file: selectedFile,
              files: videoFiles,
              index: videoFiles.indexOf(selectedFile),
            ),
          ),
        );
      } else if (audioFiles.isNotEmpty &&
          videoFiles.isEmpty &&
          documentFiles.isEmpty) {
        AudioPlaybackHelper.playAudio(ref, selectedFile, audioFiles);
      } else if (documentFiles.isNotEmpty &&
          videoFiles.isEmpty &&
          audioFiles.isEmpty) {
        final supportedDocs = documentFiles.where(
          (f) =>
              f.extension == '.pdf' ||
              f.extension == '.epub' ||
              f.extension == '.txt' ||
              f.extension == '.json',
        );

        if (supportedDocs.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => UnifiedReaderScreen(
                documentUrl: selectedFile.path,
                title: selectedFile.name,
                source: 'local',
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('No supported document files found'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Selected location contains mixed file types'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file picker: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVideoEditor() async {
    Navigator.pop(context); // Close drawer if open

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      final videoPath = result.files.single.path;
      if (videoPath == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorScreen(videoPath: videoPath),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open video editor: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    Navigator.pop(context); // Close drawer

    showAboutDialog(
      context: context,
      applicationName: 'Slideup Media Player',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.play_circle_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'A professional multi-format media player with advanced features for videos, audio, and documents.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.video_library, size: 16),
              label: const Text('Video'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
            Chip(
              avatar: const Icon(Icons.music_note, size: 16),
              label: const Text('Audio'),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
            Chip(
              avatar: const Icon(Icons.article, size: 16),
              label: const Text('Documents'),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          ],
        ),
      ],
    );
  }
}

// ==================== HELPER CLASSES ====================

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
      ),
      title: Row(
        children: [
          Text(title),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}

import 'package:flutter/material.dart';

import '../screens/txt_reader_screen.dart';
import 'bookmarks_tab.dart';
import 'translations_tab.dart';
import 'settings_tab.dart';
import 'audio_tab.dart';

class LeftPanel extends StatefulWidget {
  final TxtReaderScreenState readerState;

  const LeftPanel({super.key, required this.readerState});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _panelWidth {
    final screenWidth = widget.readerState.screenSize.width;
    final width = screenWidth * 0.85;
    return width.clamp(280.0, 400.0);
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.readerState.leftPanelAnimation;
    if (animation == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final slideValue = animation.value;
        if (slideValue == 0 && !widget.readerState.showLeftPanel) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Backdrop
            if (slideValue > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => widget.readerState.toggleLeftPanel(false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5 * slideValue),
                  ),
                ),
              ),

            // Panel
            Positioned(
              left: -_panelWidth * (1 - slideValue),
              top: 0,
              bottom: 0,
              width: _panelWidth,
              child: _buildPanelContent(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanelContent() {
    final backgroundColor = widget.readerState.getControlsBackgroundColor();
    final textColor = widget.readerState.getTextColor();
    final safeArea = widget.readerState.safeArea;

    return Material(
      elevation: 16,
      color: backgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: safeArea.top + 8,
              left: 16,
              right: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.readerState.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  onPressed: () => widget.readerState.toggleLeftPanel(false),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Tab Bar
          _buildTabBar(textColor),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BookmarksTab(readerState: widget.readerState),
                TranslationsTab(readerState: widget.readerState),
                AudioTab(readerState: widget.readerState),
                SettingsTab(readerState: widget.readerState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color textColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: textColor.withValues(alpha: 0.6),
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
        ),
        labelPadding: EdgeInsets.zero, // Compact tabs
        tabs: const [
          Tab(
            icon: Icon(Icons.bookmark_rounded, size: 20),
            text: 'Bookmarks',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          Tab(
            icon: Icon(Icons.translate_rounded, size: 20),
            text: 'Translate',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          Tab(
            icon: Icon(Icons.audiotrack, size: 20),
            text: 'Audio',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          Tab(
            icon: Icon(Icons.settings_rounded, size: 20),
            text: 'Settings',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
        ],
      ),
    );
  }
}

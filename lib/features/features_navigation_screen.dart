import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:slideup/features/documents/utils/reader_utils.dart';

import '../features/epub_reader/downloaded_epub_catalogue.dart';
import '../features/txt_reader/screens/text_downloads_screen.dart';
import '../features/documents/screens/pdf_search_screen.dart';
import '../features/documents/widgets/downloaded_pdf_widget.dart';
import '../features/documents/screens/unified_reader_screen.dart';

class FeaturesNavigationScreen extends ConsumerStatefulWidget {
  const FeaturesNavigationScreen({super.key});

  @override
  ConsumerState<FeaturesNavigationScreen> createState() =>
      _FeaturesNavigationScreenState();
}

class _FeaturesNavigationScreenState
    extends ConsumerState<FeaturesNavigationScreen> {
  int _currentIndex = 0;

  // Page controller for smooth transitions
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          HomeTab(),
          PdfSearchScreen(),
          DownloadedEpubCatalogue(),
          TextDownloadsScreen(),
          DownloadedPdfWidget(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'EPUB',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Text',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf_rounded),
            label: 'PDF',
          ),
        ],
      ),
    );
  }
}

/// Home Tab with Quick Access
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(context),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // Recent Activity
              _buildSectionTitle(context, 'Continue Reading'),
              const SizedBox(height: 12),
              _buildRecentActivity(context),
              const SizedBox(height: 24),

              // Library Stats
              _buildSectionTitle(context, 'Your Library'),
              const SizedBox(height: 12),
              _buildLibraryStats(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;

    if (hour < 12) {
      greeting = 'Good Morning';
      icon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.wb_sunny_rounded;
    } else {
      greeting = 'Good Evening';
      icon = Icons.nights_stay_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to explore your library?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionCard(
              icon: Icons.add_rounded,
              label: 'Add URL',
              color: Colors.blue,
              onTap: () => _showAddUrlDialog(context),
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
            ),
            _QuickActionCard(
              icon: Icons.folder_open_rounded,
              label: 'Open File',
              color: Colors.orange,
              onTap: () => _pickFile(context),
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
            ),
            _QuickActionCard(
              icon: Icons.search_rounded,
              label: 'Search Archive',
              color: Colors.purple,
              onTap: () => _navigateToTab(context, 3),
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
            ),
            _QuickActionCard(
              icon: Icons.history_rounded,
              label: 'Recent',
              color: Colors.teal,
              onTap: () => _showRecentFiles(context),
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent reading activity',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Start reading to see your progress here',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            icon: Icons.search_rounded,
            label: 'Search',
            value: '0',
            color: const Color.fromARGB(255, 39, 176, 98),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.auto_stories_rounded,
            label: 'EPUB',
            value: '0',
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.description_rounded,
            label: 'Text',
            value: '0',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            value: '0',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  void _openSettings(BuildContext context) {
    // Navigate to settings
  }

  void _showAddUrlDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddUrlSheet(),
    );
  }

  void _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf', 'txt'],
        allowMultiple: false,
      );
      if (result != null) {
        final file = result.files.first;
        final extension = file.extension;
        final fileName = file.name;
        if (extension == 'epub') {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UnifiedReaderScreen(
                title: fileName,
                documentUrl: file.path!,
                forceType: DocumentType.epub,
                source: 'local',
              ),
            ),
          );
        } else if (extension == 'pdf') {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UnifiedReaderScreen(
                title: fileName,
                documentUrl: file.path!,
                forceType: DocumentType.pdf,
                source: 'local',
              ),
            ),
          );
        } else if (extension == 'txt') {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UnifiedReaderScreen(
                title: fileName,
                documentUrl: file.path!,
                forceType: DocumentType.txt,
                source: 'local',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _navigateToTab(BuildContext context, int index) {
    // Find FeaturesNavigationScreen and switch tab
    final mainNav = context
        .findAncestorStateOfType<_FeaturesNavigationScreenState>();
    mainNav?._onTabTapped(index);
  }

  void _showRecentFiles(BuildContext context) {
    // Show recent files
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddUrlSheet extends StatefulWidget {
  const _AddUrlSheet();

  @override
  State<_AddUrlSheet> createState() => _AddUrlSheetState();
}

class _AddUrlSheetState extends State<_AddUrlSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String _selectedType = 'auto';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validate);
  }

  void _validate() {
    final isValid =
        Uri.tryParse(_urlController.text.trim())?.hasAbsolutePath ?? false;
    if (_isValid != isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;

    final url = _urlController.text.trim();
    final title = _titleController.text.trim();

    Navigator.pop(context);

    // Determine which screen to open based on file type
    final ext = _detectFileType(url);

    switch (ext) {
      case 'epub':
        // Navigate to EPUB with URL
        break;
      case 'txt':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextDownloadsScreen(
              url: url,
              title: title.isNotEmpty ? title : null,
            ),
          ),
        );
        break;
      case 'pdf':
        // Navigate to PDF
        break;
      default:
        // Auto-detect or show error
        break;
    }
  }

  String _detectFileType(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.epub')) return 'epub';
    if (lower.endsWith('.txt')) return 'txt';
    if (lower.endsWith('.pdf')) return 'pdf';
    return _selectedType;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + safePadding + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text(
              'Add from URL',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // URL Field
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/book.epub',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _urlController.text = data!.text!;
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // File Type Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'auto', label: Text('Auto')),
                ButtonSegment(value: 'epub', label: Text('EPUB')),
                ButtonSegment(value: 'txt', label: Text('Text')),
                ButtonSegment(value: 'pdf', label: Text('PDF')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _isValid ? _submit : null,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download & Open'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

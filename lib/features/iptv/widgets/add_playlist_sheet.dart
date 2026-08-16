import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/iptv_providers.dart';
import '../services/iptv_languages.dart';

/// Bottom sheet to add a playlist: M3U URL, local file, or XTream credentials.
class AddPlaylistSheet extends ConsumerStatefulWidget {
  const AddPlaylistSheet({super.key});

  @override
  ConsumerState<AddPlaylistSheet> createState() => _AddPlaylistSheetState();
}

class _AddPlaylistSheetState extends ConsumerState<AddPlaylistSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  final _xtreamServerController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();
  final _xtreamNameController = TextEditingController();

  bool _adding = false;
  String? _error;
  String? _selectedFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _xtreamServerController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    _xtreamNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.single.path);
    }
  }

  Future<void> _addFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a playlist URL.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref
          .read(iptvPlaylistsProvider.notifier)
          .addFromUrl(url: url, name: _nameController.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _error = 'Failed to load playlist.\n$e';
        });
      }
    }
  }

  Future<void> _addFromFile() async {
    final path = _selectedFile;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'Please pick a .m3u / .m3u8 file.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref
          .read(iptvPlaylistsProvider.notifier)
          .addFromFile(path: path, name: _nameController.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _error = 'Failed to read playlist.\n$e';
        });
      }
    }
  }

  Future<void> _addFromXtream() async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(iptvPlaylistsProvider.notifier).addFromXtream(
            server: _xtreamServerController.text,
            username: _xtreamUserController.text,
            password: _xtreamPassController.text,
            name: _xtreamNameController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _error = 'Failed to connect.\n$e';
        });
      }
    }
  }

  Future<void> _addByLanguage(IptvLanguage language) async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref
          .read(iptvPlaylistsProvider.notifier)
          .addFromUrl(
            url: language.playlistUrl,
            name: '${language.name} TV',
            language: language.name,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _error = 'Failed to load ${language.name} playlist.\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add playlist',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'URL'),
                Tab(text: 'File'),
                Tab(text: 'XTream'),
                Tab(text: 'Languages'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 340,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUrlTab(context),
                  _buildFileTab(context),
                  _buildXtreamTab(context),
                  _buildLanguagesTab(context),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Playlist URL',
              hintText: 'https://example.com/playlist.m3u',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'My channels',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _adding ? null : _addFromUrl,
            icon: _adding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Download & add'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _adding ? null : _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose .m3u file'),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _adding ? null : _addFromFile,
            icon: _adding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Add local playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildXtreamTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _xtreamServerController,
            decoration: const InputDecoration(
              labelText: 'Server',
              hintText: 'http://host:port',
              prefixIcon: Icon(Icons.dns),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _xtreamUserController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _xtreamPassController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _xtreamNameController,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _adding ? null : _addFromXtream,
            icon: _adding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            label: const Text('Connect & add'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemCount: kIptvLanguages.length,
      itemBuilder: (context, index) {
        final language = kIptvLanguages[index];
        return InkWell(
          onTap: _adding ? null : () => _addByLanguage(language),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              language.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
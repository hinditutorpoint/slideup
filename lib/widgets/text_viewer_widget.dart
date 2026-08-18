import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../features/private_browser/private_browser_screen.dart';

class TextViewerWidget extends StatefulWidget {
  final String filePath;
  final String? content;

  const TextViewerWidget({super.key, required this.filePath, this.content});

  @override
  State<TextViewerWidget> createState() => _TextViewerWidgetState();
}

class _TextViewerWidgetState extends State<TextViewerWidget> {
  String? _content;
  bool _isLoading = true;
  String? _error;
  bool _isHtml = false;
  double _fontSize = 14.0;
  bool _wordWrap = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      String content;
      if (widget.content != null) {
        content = widget.content!;
      } else {
        final file = File(widget.filePath);
        content = await file.readAsString();
      }

      final extension = widget.filePath.toLowerCase().split('.').last;
      _isHtml = ['html', 'htm'].contains(extension);

      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load file: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getFileName()),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() {
              _fontSize = (_fontSize - 2).clamp(8.0, 32.0);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() {
              _fontSize = (_fontSize + 2).clamp(8.0, 32.0);
            }),
          ),
          if (!_isHtml)
            IconButton(
              icon: Icon(_wordWrap ? Icons.wrap_text : Icons.short_text),
              onPressed: () => setState(() => _wordWrap = !_wordWrap),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadContent),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadContent, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_content == null) {
      return const Center(child: Text('No content'));
    }

    return _isHtml ? _buildHtmlView() : _buildTextView();
  }

  Widget _buildHtmlView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: _content!,
        style: {"*": Style(fontSize: FontSize(_fontSize))},
        onLinkTap: (url, _, __) {
          if (url != null) _launchUrl(url);
        },
      ),
    );
  }

  Widget _buildTextView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: TextStyle(
          fontSize: _fontSize,
          fontFamily: 'monospace',
          height: 1.4,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  String _getFileName() {
    return widget.filePath.split('/').last;
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrivateBrowserScreen(initialUrl: url),
        ),
      );
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}

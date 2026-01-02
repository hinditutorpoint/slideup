import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_providers.dart';

class VideoSearchBar extends ConsumerStatefulWidget {
  const VideoSearchBar({super.key});

  @override
  ConsumerState<VideoSearchBar> createState() => _VideoSearchBarState();
}

class _VideoSearchBarState extends ConsumerState<VideoSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(videoSearchProvider.notifier).search(query);
    });
  }

  void _onSubmitted(String query) {
    _debounce?.cancel();
    ref.read(videoSearchProvider.notifier).search(query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(videoSearchProvider.notifier).search('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search videos on Archive.org...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          fillColor: colorScheme.surfaceContainerHighest,
        ),
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: _onSubmitted,
      ),
    );
  }
}

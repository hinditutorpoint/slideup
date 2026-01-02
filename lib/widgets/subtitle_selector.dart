import 'package:flutter/material.dart';
import '../models/subtitle_track.dart';

class SubtitleSelector extends StatefulWidget {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? currentTrack;
  final Function(SubtitleTrack?) onTrackSelected;
  final VoidCallback? onTranscribe;
  final VoidCallback? onTranslate;
  final VoidCallback? onLoadExternal;
  final bool isTranscribing;
  final bool isTranslating;
  final bool isLoading;

  const SubtitleSelector({
    super.key,
    required this.tracks,
    this.currentTrack,
    required this.onTrackSelected,
    this.onTranscribe,
    this.onTranslate,
    this.onLoadExternal,
    this.isTranscribing = false,
    this.isTranslating = false,
    this.isLoading = false,
  });

  @override
  State<SubtitleSelector> createState() => _SubtitleSelectorState();
}

class _SubtitleSelectorState extends State<SubtitleSelector> {
  SubtitleTrack? _selectedTrack;

  @override
  void initState() {
    super.initState();
    _selectedTrack = widget.currentTrack;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Header
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'Subtitles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.isLoading ||
                          widget.isTranscribing ||
                          widget.isTranslating) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${widget.tracks.length} available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Off option
                  ListTile(
                    leading: Icon(
                      _selectedTrack == null
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: _selectedTrack == null
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    title: Text(
                      'Off',
                      style: TextStyle(
                        fontWeight: _selectedTrack == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedTrack == null
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    subtitle: const Text('No subtitles'),
                    trailing: const Icon(Icons.subtitles_off),
                    onTap: widget.isLoading
                        ? null
                        : () {
                            setState(() => _selectedTrack = null);
                            widget.onTrackSelected(null);
                            Navigator.pop(context);
                          },
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // ✅ Available tracks
                  ...widget.tracks.map((track) {
                    final isSelected = _selectedTrack?.id == track.id;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              )
                            : null,
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: ListTile(
                        enabled: !widget.isLoading,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Stack(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                            if (track.isEmbedded)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(
                                  Icons.video_file,
                                  size: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            if (track.isExternal)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(
                                  Icons.attach_file,
                                  size: 12,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                track.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ),

                            // ✅ Type badges
                            ...() {
                              final badges = <Widget>[];

                              if (track.isEmbedded) {
                                badges.add(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'EMBEDDED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (track.isExternal) {
                                badges.add(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'EXTERNAL',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (track.isTranscribed) {
                                badges.add(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'AI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return badges;
                            }(),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(track.language),
                            if (track.format != null)
                              Text(
                                track.format!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        onTap: widget.isLoading
                            ? null
                            : () {
                                setState(() => _selectedTrack = track);
                                widget.onTrackSelected(track);
                                Navigator.pop(context);
                              },
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ✅ Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ✅ AI Transcribe button
                        if (widget.onTranscribe != null)
                          ElevatedButton.icon(
                            onPressed: widget.isTranscribing
                                ? null
                                : widget.onTranscribe,
                            icon: widget.isTranscribing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                              widget.isTranscribing
                                  ? 'Generating AI Subtitles...'
                                  : 'Generate AI Subtitles',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // ✅ Translate button
                        if (widget.onTranslate != null &&
                            _selectedTrack != null)
                          ElevatedButton.icon(
                            onPressed: widget.isTranslating
                                ? null
                                : widget.onTranslate,
                            icon: widget.isTranslating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.translate),
                            label: Text(
                              widget.isTranslating
                                  ? 'Translating...'
                                  : 'Translate Subtitles',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // ✅ Load external button
                        if (widget.onLoadExternal != null)
                          OutlinedButton.icon(
                            onPressed: widget.isLoading
                                ? null
                                : widget.onLoadExternal,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Load External Subtitle'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

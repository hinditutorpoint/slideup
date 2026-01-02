import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class AudioTab extends StatelessWidget {
  final String? attachedAudioPath;
  final Function(String?) onAudioChanged;
  final VoidCallback onExtractAudio;

  const AudioTab({
    super.key,
    required this.attachedAudioPath,
    required this.onAudioChanged,
    required this.onExtractAudio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attach audio section
              _buildSection(
                title: 'Attach Audio',
                icon: Icons.add_circle_outline,
                isCompact: isCompact,
                child: attachedAudioPath != null
                    ? _buildAttachedAudio(context, isCompact)
                    : _buildAttachButton(context, isCompact),
              ),

              SizedBox(height: isCompact ? 16 : 24),

              // Extract audio section
              _buildSection(
                title: 'Extract Audio',
                icon: Icons.download,
                isCompact: isCompact,
                child: _buildExtractButton(isCompact),
              ),

              SizedBox(height: isCompact ? 16 : 24),

              // Audio options when attached
              if (attachedAudioPath != null) ...[
                _buildSection(
                  title: 'Audio Options',
                  icon: Icons.tune,
                  isCompact: isCompact,
                  child: _buildAudioOptions(isCompact),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isCompact,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[500], size: isCompact ? 16 : 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),
        child,
      ],
    );
  }

  Widget _buildAttachButton(BuildContext context, bool isCompact) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _pickAudio(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 16 : 20),
          child: Column(
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white70,
                size: isCompact ? 28 : 32,
              ),
              SizedBox(height: isCompact ? 8 : 10),
              Text(
                'Tap to select audio file',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              SizedBox(height: isCompact ? 2 : 4),
              Text(
                'MP3, AAC, WAV, FLAC',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedAudio(BuildContext context, bool isCompact) {
    final fileName = attachedAudioPath!.split('/').last;

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.music_note,
              color: Colors.green,
              size: isCompact ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Audio attached',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: isCompact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              onAudioChanged(null);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              Icons.close,
              color: Colors.red[400],
              size: isCompact ? 18 : 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractButton(bool isCompact) {
    return Material(
      color: Colors.blue.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onExtractAudio,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.audio_file,
                color: Colors.blue,
                size: isCompact ? 20 : 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Extract Audio from Video',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioOptions(bool isCompact) {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.volume_up,
          title: 'Replace original audio',
          subtitle: 'Mute video audio',
          isCompact: isCompact,
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          icon: Icons.merge_type,
          title: 'Mix with original',
          subtitle: 'Blend both audio tracks',
          isCompact: isCompact,
          isSelected: true,
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompact,
    bool isSelected = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.red : Colors.grey[500],
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isCompact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: Colors.red,
              size: isCompact ? 18 : 20,
            ),
        ],
      ),
    );
  }

  Future<void> _pickAudio(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        onAudioChanged(result.files.first.path);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('❌ Pick audio error: $e');
    }
  }
}

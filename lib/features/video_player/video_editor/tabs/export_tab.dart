import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

class ExportTab extends StatelessWidget {
  final ExportPreset selectedPreset;
  final Function(ExportPreset) onPresetChanged;
  final VoidCallback onExport;
  final VoidCallback onExportWithOptions;
  final Duration trimDuration;
  final bool hasColorGrading;
  final bool hasMergeQueue;
  final bool hasAttachedAudio;

  const ExportTab({
    super.key,
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.onExport,
    required this.onExportWithOptions,
    required this.trimDuration,
    required this.hasColorGrading,
    required this.hasMergeQueue,
    required this.hasAttachedAudio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 350;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              _buildSummary(isCompact),
              SizedBox(height: isCompact ? 16 : 20),

              // Presets
              _buildPresetsSection(isCompact),
              SizedBox(height: isCompact ? 16 : 20),

              // Format options
              _buildFormatSection(isCompact),
              SizedBox(height: isCompact ? 16 : 20),

              // Export buttons
              _buildExportButtons(isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSummaryChip(
                Icons.timer,
                _formatDuration(trimDuration),
                Colors.blue,
                isCompact,
              ),
              if (hasColorGrading)
                _buildSummaryChip(
                  Icons.palette,
                  'Color',
                  Colors.purple,
                  isCompact,
                ),
              if (hasMergeQueue)
                _buildSummaryChip(
                  Icons.merge,
                  'Merge',
                  Colors.orange,
                  isCompact,
                ),
              if (hasAttachedAudio)
                _buildSummaryChip(
                  Icons.music_note,
                  'Audio',
                  Colors.green,
                  isCompact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    IconData icon,
    String label,
    Color color,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: isCompact ? 10 : 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality Preset',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        SizedBox(
          height: isCompact ? 70 : 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ExportPreset.defaultPresets.length,
            itemBuilder: (context, index) {
              final preset = ExportPreset.defaultPresets[index];
              final isSelected = selectedPreset.id == preset.id;

              return GestureDetector(
                onTap: () {
                  onPresetChanged(preset);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: isCompact ? 80 : 90,
                  margin: const EdgeInsets.only(right: 10),
                  padding: EdgeInsets.all(isCompact ? 8 : 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.white,
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      Text(
                        preset.description,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: isCompact ? 8 : 9,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Output Format',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VideoFormat.values.map((format) {
            final isSelected = selectedPreset.format == format;
            return GestureDetector(
              onTap: () {
                // Would need to create new preset with different format
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 14 : 16,
                  vertical: isCompact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.transparent,
                  ),
                ),
                child: Text(
                  format.name.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.red : Colors.white70,
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExportButtons(bool isCompact) {
    return Column(
      children: [
        // Quick export
        Material(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onExport,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload,
                    color: Colors.white,
                    size: isCompact ? 18 : 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Export Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: isCompact ? 10 : 12),

        // Custom export
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onExportWithOptions,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.settings,
                    color: Colors.white70,
                    size: isCompact ? 16 : 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Export Options',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isCompact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

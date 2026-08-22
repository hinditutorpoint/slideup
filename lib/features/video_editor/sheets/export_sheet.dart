import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/file_picker_service.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart' hide ExportJob;

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportPreset _selectedPreset = ExportPreset.defaultPresets[2]; // 1080p HD
  String? _customOutputPath;
  bool _showAdvancedOptions = false;
  bool _showRecentExports = false;

  // Export options
  bool _includeTextOverlays = true;
  bool _includeImageOverlays = true;
  bool _includeAudioTracks = true;
  bool _applyColorGrading = true;
  bool _runInBackground = false;

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportProvider);
    final project = ref.watch(currentProjectProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Compact Header
          _buildCompactHeader(exportState),

          // Main Content
          if (exportState.isExporting)
            Expanded(child: _buildCompactProgress(exportState))
          else if (exportState.isCompleted && exportState.outputPath != null)
            Expanded(child: _buildCompactComplete(exportState))
          else
            Expanded(child: _buildCompactExportView(project)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎯 COMPACT HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactHeader(ExportState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getStatusColor(state.status).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(state.status),
              color: _getStatusColor(state.status),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Export Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.message != null)
                  Text(
                    state.message!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Actions
          if (state.isExporting)
            TextButton(
              onPressed: _cancelExport,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: Colors.white54,
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📦 COMPACT EXPORT VIEW
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactExportView(VideoProject? project) {
    if (project == null) {
      return const Center(
        child: Text(
          'No project to export',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Preview (Compact)
          _buildCompactProjectPreview(project),
          const SizedBox(height: 16),

          // Quick Presets (Horizontal Scroll)
          _buildQuickPresets(),
          const SizedBox(height: 12),

          // Custom Preset Button
          _buildCustomPresetButton(),
          const SizedBox(height: 16),

          // Export Location
          _buildExportLocationPicker(),
          const SizedBox(height: 12),

          // Advanced Options (Collapsible)
          _buildAdvancedOptionsToggle(),
          if (_showAdvancedOptions) ...[
            const SizedBox(height: 12),
            _buildCompactAdvancedOptions(),
          ],
          const SizedBox(height: 12),

          // Export Info Summary
          _buildExportSummary(project),
          const SizedBox(height: 16),

          // Export Button
          _buildCompactExportButton(),
          const SizedBox(height: 12),

          // Recent Exports Toggle
          _buildRecentExportsToggle(),
          if (_showRecentExports) ...[
            const SizedBox(height: 12),
            _buildCompactRecentExports(),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🖼️ COMPACT PROJECT PREVIEW
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactProjectPreview(VideoProject project) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.purple.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: project.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(project.thumbnail!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.movie, color: Colors.white24, size: 24),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(project.effectiveDuration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.layers,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${project.totalOverlayCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⚡ QUICK PRESETS (Horizontal Chips)
  // ═══════════════════════════════════════════════════════

  Widget _buildQuickPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedPreset.qualityLabel,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ExportPreset.defaultPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = ExportPreset.defaultPresets[index];
              final isSelected = _selectedPreset.id == preset.id;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedPreset = preset);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPresetIcon(preset),
                        size: 14,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  // ═══════════════════════════════════════════════════════
  // ⚙️ CUSTOM PRESET BUTTON
  // ═══════════════════════════════════════════════════════

  Widget _buildCustomPresetButton() {
    return GestureDetector(
      onTap: _showCustomPresetDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune, size: 16, color: Colors.amber.shade300),
            const SizedBox(width: 8),
            Text(
              'Custom Export Settings',
              style: TextStyle(
                color: Colors.amber.shade200,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: Colors.amber.shade300),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📁 EXPORT LOCATION PICKER
  // ═══════════════════════════════════════════════════════

  Widget _buildExportLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export Location',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickExportLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _customOutputPath ?? 'Default (Movies/Exports)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔽 ADVANCED OPTIONS TOGGLE
  // ═══════════════════════════════════════════════════════

  Widget _buildAdvancedOptionsToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showAdvancedOptions = !_showAdvancedOptions);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.settings,
              size: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Advanced Options',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: _showAdvancedOptions ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⚙️ COMPACT ADVANCED OPTIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactAdvancedOptions() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildCompactOption(
            'Text Overlays',
            _includeTextOverlays,
            Icons.text_fields,
            Colors.orange,
            (v) => setState(() => _includeTextOverlays = v),
          ),
          const SizedBox(height: 6),
          _buildCompactOption(
            'Image Overlays',
            _includeImageOverlays,
            Icons.image,
            Colors.green,
            (v) => setState(() => _includeImageOverlays = v),
          ),
          const SizedBox(height: 6),
          _buildCompactOption(
            'Audio Tracks',
            _includeAudioTracks,
            Icons.audiotrack,
            Colors.purple,
            (v) => setState(() => _includeAudioTracks = v),
          ),
          const SizedBox(height: 6),
          _buildCompactOption(
            'Color Grading',
            _applyColorGrading,
            Icons.color_lens,
            Colors.blue,
            (v) => setState(() => _applyColorGrading = v),
          ),
          const SizedBox(height: 6),
          _buildCompactOption(
            'Background Export',
            _runInBackground,
            Icons.battery_saver,
            Colors.teal,
            (v) => setState(() => _runInBackground = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOption(
    String label,
    bool value,
    IconData icon,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📊 EXPORT SUMMARY
  // ═══════════════════════════════════════════════════════

  Widget _buildExportSummary(VideoProject project) {
    final estimatedSize = _calculateEstimatedSize(project);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            Icons.aspect_ratio,
            _selectedPreset.qualityLabel,
            'Resolution',
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildSummaryItem(
            Icons.timer,
            _formatDuration(project.effectiveDuration),
            'Duration',
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildSummaryItem(Icons.storage, estimatedSize, 'Est. Size'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🚀 COMPACT EXPORT BUTTON
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _startExport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Start Export',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📜 RECENT EXPORTS TOGGLE
  // ═══════════════════════════════════════════════════════

  Widget _buildRecentExportsToggle() {
    final exportState = ref.watch(exportProvider);
    final count = exportState.recentExports.length;

    return GestureDetector(
      onTap: () {
        setState(() => _showRecentExports = !_showRecentExports);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Recent Exports',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            AnimatedRotation(
              turns: _showRecentExports ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📋 COMPACT RECENT EXPORTS
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactRecentExports() {
    final exportState = ref.watch(exportProvider);
    final exports = exportState.recentExports.take(5).toList();

    if (exports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 32,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 8),
              Text(
                'No recent exports',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: exports.map((job) => _buildCompactExportItem(job)).toList(),
      ),
    );
  }

  Widget _buildCompactExportItem(ExportJob job) {
    final statusColor = _getJobStatusColor(job.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              job.status == ExportJobStatus.completed
                  ? Icons.check_circle
                  : job.status == ExportJobStatus.failed
                  ? Icons.error
                  : Icons.pending,
              color: statusColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.projectId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(job.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (job.status == ExportJobStatus.completed &&
              job.outputPath.isNotEmpty) ...[
            IconButton(
              onPressed: () => _shareFile(job.outputPath),
              icon: const Icon(Icons.share, size: 16),
              color: Colors.blue,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              onPressed: () => _deleteExport(job.id),
              icon: const Icon(Icons.delete_outline, size: 16),
              color: Colors.red.withValues(alpha: 0.7),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📊 COMPACT PROGRESS
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactProgress(ExportState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress Ring
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(state.status),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.progressPercent,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.estimated != null)
                      Text(
                        state.etaFormatted,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status
          Text(
            state.message ?? 'Processing...',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Elapsed: ${_formatDuration(state.elapsed)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COMPACT COMPLETE
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactComplete(ExportState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Export Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your video has been exported',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),

          // File Info
          if (state.outputPath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_file, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.outputPath!.split('/').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getFileSize(state.outputPath!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFile(state.outputPath!),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Play', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareFile(state.outputPath!),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(exportProvider.notifier).reset(),
            child: const Text('Export Another', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🛠️ CUSTOM PRESET DIALOG
  // ═══════════════════════════════════════════════════════

  void _showCustomPresetDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CustomPresetDialog(
        initialPreset: _selectedPreset,
        onPresetSelected: (preset) {
          setState(() => _selectedPreset = preset);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎬 ACTIONS
  // ═══════════════════════════════════════════════════════

  Future<void> _startExport() async {
    HapticFeedback.mediumImpact();

    final result = await ref
        .read(exportProvider.notifier)
        .startTimelineExport(
          preset: _selectedPreset,
          includeTextOverlays: _includeTextOverlays,
          includeImageOverlays: _includeImageOverlays,
          includeAudioTracks: _includeAudioTracks,
          applyColorGrading: _applyColorGrading,
        );

    if (result.isFailure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelExport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Cancel Export?'),
        content: const Text('The current export will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel Export',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(exportProvider.notifier).cancelExport();
    }
  }

  void _deleteExport(String jobId) {
    ref.read(exportProvider.notifier).deleteExport(jobId);
    HapticFeedback.lightImpact();
  }

  Future<void> _pickExportLocation() async {
    try {
      final result = await FilePickerService.getDirectoryPath();
      if (result != null) {
        setState(() => _customOutputPath = result);
      }
    } catch (e) {
      debugPrint('Error picking location: $e');
    }
  }

  Future<void> _openFile(String path) async {
    // Use open_file package or similar
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening file...')));
  }

  Future<void> _shareFile(String path) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════

  IconData _getPresetIcon(ExportPreset preset) {
    switch (preset.quality) {
      case VideoQuality.ultra:
        return Icons.hd;
      case VideoQuality.high:
        return Icons.high_quality;
      case VideoQuality.medium:
        return Icons.sd;
      case VideoQuality.low:
        return Icons.compress;
      case VideoQuality.original:
        return Icons.auto_awesome;
    }
  }

  Color _getStatusColor(ExportStatus status) {
    switch (status) {
      case ExportStatus.idle:
        return Colors.grey;
      case ExportStatus.preparing:
        return Colors.orange;
      case ExportStatus.processing:
      case ExportStatus.encoding:
        return Colors.blue;
      case ExportStatus.saving:
        return Colors.teal;
      case ExportStatus.completed:
        return Colors.green;
      case ExportStatus.failed:
        return Colors.red;
      case ExportStatus.cancelled:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(ExportStatus status) {
    switch (status) {
      case ExportStatus.idle:
        return Icons.upload_file;
      case ExportStatus.preparing:
        return Icons.hourglass_top;
      case ExportStatus.processing:
        return Icons.memory;
      case ExportStatus.encoding:
        return Icons.video_settings;
      case ExportStatus.saving:
        return Icons.save;
      case ExportStatus.completed:
        return Icons.check_circle;
      case ExportStatus.failed:
        return Icons.error;
      case ExportStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getJobStatusColor(ExportJobStatus status) {
    switch (status) {
      case ExportJobStatus.pending:
        return Colors.orange;
      case ExportJobStatus.running:
        return Colors.blue;
      case ExportJobStatus.completed:
        return Colors.green;
      case ExportJobStatus.failed:
        return Colors.red;
      case ExportJobStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _calculateEstimatedSize(VideoProject project) {
    final seconds = project.effectiveDuration.inSeconds;
    final bitrate = _selectedPreset.bitrate ?? 8000;
    final sizeKB = (seconds * bitrate) / 8;

    if (sizeKB < 1024) {
      return '${sizeKB.toStringAsFixed(0)} KB';
    } else if (sizeKB < 1024 * 1024) {
      return '${(sizeKB / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeKB / (1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _getFileSize(String path) {
    try {
      final file = File(path);
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return 'Unknown';
    }
  }
}

// ═══════════════════════════════════════════════════════
// ⚙️ CUSTOM PRESET DIALOG
// ═══════════════════════════════════════════════════════

class CustomPresetDialog extends StatefulWidget {
  final ExportPreset initialPreset;
  final Function(ExportPreset) onPresetSelected;

  const CustomPresetDialog({
    super.key,
    required this.initialPreset,
    required this.onPresetSelected,
  });

  @override
  State<CustomPresetDialog> createState() => _CustomPresetDialogState();
}

class _CustomPresetDialogState extends State<CustomPresetDialog> {
  late int _width;
  late int _height;
  late int _bitrate;
  late int _fps;
  late int _audioBitrate;
  late VideoQuality _quality;

  @override
  void initState() {
    super.initState();
    _width = widget.initialPreset.width ?? 1920;
    _height = widget.initialPreset.height ?? 1080;
    _bitrate = widget.initialPreset.bitrate ?? 8000;
    _fps = widget.initialPreset.fps ?? 30;
    _audioBitrate = widget.initialPreset.audioBitrate ?? 128;
    _quality = widget.initialPreset.quality;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Custom Export Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.white54,
                ),
              ],
            ),
          ),

          // Settings
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow('Resolution Width', '$_width px', () {
                    // Show number picker
                  }),
                  _buildSettingRow('Resolution Height', '$_height px', () {
                    // Show number picker
                  }),
                  _buildSettingRow('Video Bitrate', '$_bitrate kbps', () {
                    // Show number picker
                  }),
                  _buildSettingRow('Frame Rate', '$_fps fps', () {
                    // Show number picker
                  }),
                  _buildSettingRow('Audio Bitrate', '$_audioBitrate kbps', () {
                    // Show number picker
                  }),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _applyCustomSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Apply Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit,
              size: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCustomSettings() {
    final customPreset = ExportPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Custom',
      quality: _quality,
      width: _width,
      height: _height,
      bitrate: _bitrate,
      fps: _fps,
      audioBitrate: _audioBitrate,
    );

    widget.onPresetSelected(customPreset);
  }
}

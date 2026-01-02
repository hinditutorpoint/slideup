import 'package:flutter/material.dart';
import '../models/download_model.dart';
import '../services/model_import_service.dart';

class ModelImportDialog extends StatefulWidget {
  final ModelImportService importService;
  final Function(DownloadedModel model) onImportComplete;

  const ModelImportDialog({
    super.key,
    required this.importService,
    required this.onImportComplete,
  });

  @override
  State<ModelImportDialog> createState() => _ModelImportDialogState();
}

class _ModelImportDialogState extends State<ModelImportDialog> {
  String? _selectedPath;
  ModelValidationResult? _validation;
  SherpaModelType _modelType = SherpaModelType.stt;
  final _nameController = TextEditingController();
  final _languageController = TextEditingController(text: 'en');

  bool _isValidating = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatus = '';
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final path = await widget.importService.pickFile();
    if (path != null) await _validatePath(path);
  }

  Future<void> _pickFolder() async {
    final path = await widget.importService.pickFolder();
    if (path != null) await _validatePath(path);
  }

  Future<void> _validatePath(String path) async {
    setState(() {
      _selectedPath = path;
      _isValidating = true;
      _error = null;
      _validation = null;
    });

    final result = await widget.importService.validate(path);

    setState(() {
      _isValidating = false;
      _validation = result;

      if (result.isValid) {
        _modelType = result.detectedType ?? SherpaModelType.stt;
        _nameController.text = result.suggestedName ?? '';
      } else {
        _error = result.error;
      }
    });
  }

  Future<void> _import() async {
    if (_selectedPath == null || _validation?.isValid != true) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a model name');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = 'Starting...';
      _error = null;
    });

    final result = await widget.importService.importModel(
      sourcePath: _selectedPath!,
      modelType: _modelType,
      modelName: name,
      language: _languageController.text.trim(),
      onProgress: (progress, status) {
        if (mounted) {
          setState(() {
            _importProgress = progress;
            _importStatus = status;
          });
        }
      },
    );

    if (!mounted) return;

    setState(() => _isImporting = false);

    if (result.success && result.model != null) {
      widget.onImportComplete(result.model!);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSourcePicker(),
                    if (_isValidating) _buildValidating(),
                    if (_validation != null) _buildValidationResult(),
                    if (_validation?.isValid == true) _buildConfiguration(),
                    if (_isImporting) _buildProgress(),
                    if (_error != null) _buildError(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_open,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Import Local Model',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isImporting ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Source', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PickerButton(
                icon: Icons.insert_drive_file,
                label: 'File',
                subtitle: 'ZIP, TAR, ONNX',
                onTap: _isImporting ? null : _pickFile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerButton(
                icon: Icons.folder,
                label: 'Folder',
                subtitle: 'Model directory',
                onTap: _isImporting ? null : _pickFolder,
              ),
            ),
          ],
        ),
        if (_selectedPath != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPath!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isImporting)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _selectedPath = null;
                      _validation = null;
                      _error = null;
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValidating() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Validating model...'),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationResult() {
    final v = _validation!;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: v.isValid
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: v.isValid ? Colors.green : Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                v.isValid ? Icons.check_circle : Icons.error,
                color: v.isValid ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                v.isValid ? 'Valid Model' : 'Invalid Model',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: v.isValid ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (v.isValid) ...[
            const SizedBox(height: 8),
            Text('Type: ${_getTypeName(v.detectedType!)}'),
            Text('Files: ${v.files.length}'),
            Text('Size: ${_formatBytes(v.estimatedSize)}'),
          ],
        ],
      ),
    );
  }

  Widget _buildConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Configuration', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Model Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label),
          ),
          enabled: !_isImporting,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SherpaModelType>(
          value: _modelType,
          decoration: const InputDecoration(
            labelText: 'Model Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: SherpaModelType.values.map((t) {
            return DropdownMenuItem(value: t, child: Text(_getTypeName(t)));
          }).toList(),
          onChanged: _isImporting
              ? null
              : (v) {
                  if (v != null) setState(() => _modelType = v);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _languageController,
          decoration: const InputDecoration(
            labelText: 'Language',
            hintText: 'e.g., en, zh, de',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.language),
          ),
          enabled: !_isImporting,
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          LinearProgressIndicator(value: _importProgress),
          const SizedBox(height: 8),
          Text(_importStatus),
          Text(
            '${(_importProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isImporting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: (_validation?.isValid == true && !_isImporting)
                ? _import
                : null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isImporting ? 'Importing...' : 'Import'),
          ),
        ],
      ),
    );
  }

  String _getTypeName(SherpaModelType type) {
    return switch (type) {
      SherpaModelType.tts => 'Text-to-Speech',
      SherpaModelType.stt => 'Speech-to-Text',
      SherpaModelType.vad => 'Voice Activity Detection',
      SherpaModelType.speakerIdentification => 'Speaker ID',
      SherpaModelType.languageIdentification => 'Language ID',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

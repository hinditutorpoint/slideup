import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_backup_service.dart';
import '../models/backup_info.dart';

class BackupRestoreScreen extends StatefulWidget {
  final DatabaseBackupService backupService;

  const BackupRestoreScreen({Key? key, required this.backupService})
    : super(key: key);

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<BackupInfo> _backups = [];
  bool _isLoading = false;
  String? _backupPath;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadBackupPath();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await widget.backupService.getBackupsList();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  Future<void> _loadBackupPath() async {
    final path = await widget.backupService.getBackupDirectoryPath();
    setState(() => _backupPath = path);
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);

    final response = await widget.backupService.createBackup();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Backup operation completed'),
          backgroundColor: response.isSuccess ? Colors.green : Colors.red,
        ),
      );
    }

    if (response.isSuccess) {
      await _loadBackups();
    }
  }

  Future<void> _restoreFromFile() async {
    final confirm = await _showConfirmDialog(
      'Restore Database',
      'This will replace your current database. Are you sure?',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    final response = await widget.backupService.restoreFromFilePicker();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Restore operation completed'),
          backgroundColor: response.isSuccess ? Colors.green : Colors.red,
        ),
      );

      if (response.isSuccess) {
        _showRestartDialog();
      }
    }
  }

  Future<void> _restoreFromBackup(BackupInfo backup) async {
    final confirm = await _showConfirmDialog(
      'Restore Database',
      'Restore from "${backup.fileName}"?\nThis will replace your current database.',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    final response = await widget.backupService.restoreFromPath(
      backup.filePath,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Restore operation completed'),
          backgroundColor: response.isSuccess ? Colors.green : Colors.red,
        ),
      );

      if (response.isSuccess) {
        _showRestartDialog();
      }
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final confirm = await _showConfirmDialog(
      'Delete Backup',
      'Delete "${backup.fileName}"?',
    );

    if (!confirm) return;

    final success = await widget.backupService.deleteBackup(backup.filePath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup deleted' : 'Failed to delete backup'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    await _loadBackups();
  }

  Future<void> _shareBackup(BackupInfo backup) async {
    await Share.shareXFiles([
      XFile(backup.filePath),
    ], subject: 'Database Backup');
  }

  Future<void> _deleteAllBackups() async {
    final confirm = await _showConfirmDialog(
      'Delete All Backups',
      'Are you sure you want to delete all backups?',
    );

    if (!confirm) return;

    final success = await widget.backupService.deleteAllBackups();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'All backups deleted' : 'Failed to delete backups',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    await _loadBackups();
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Restart Required'),
        content: const Text(
          'Database has been restored. Please restart the app to apply changes.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          if (_backups.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteAllBackups,
              tooltip: 'Delete all backups',
            ),
        ],
      ),
      body: Column(
        children: [
          // Backup Path Info
          if (_backupPath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup Location:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(_backupPath!, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create Backup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _restoreFromFile,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore from File'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Backups List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Backups (${_backups.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadBackups,
                ),
              ],
            ),
          ),

          // Backups List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _backups.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No backups found',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _backups.length,
                    itemBuilder: (context, index) {
                      final backup = _backups[index];
                      return _BackupListItem(
                        backup: backup,
                        onRestore: () => _restoreFromBackup(backup),
                        onDelete: () => _deleteBackup(backup),
                        onShare: () => _shareBackup(backup),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BackupListItem extends StatelessWidget {
  final BackupInfo backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _BackupListItem({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storage)),
        title: Text(
          backup.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${dateFormat.format(backup.createdAt)} • ${backup.formattedSize}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'restore':
                onRestore();
                break;
              case 'share':
                onShare();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: ListTile(
                leading: Icon(Icons.restore, color: Colors.blue),
                title: Text('Restore'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share, color: Colors.green),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

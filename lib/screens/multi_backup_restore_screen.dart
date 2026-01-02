// lib/screens/multi_backup_restore_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/multi_database_backup_service.dart';
import '../models/backup_info.dart';
import '../models/database_config.dart';

class MultiBackupRestoreScreen extends StatefulWidget {
  final MultiDatabaseBackupService backupService;

  const MultiBackupRestoreScreen({Key? key, required this.backupService})
    : super(key: key);

  @override
  State<MultiBackupRestoreScreen> createState() =>
      _MultiBackupRestoreScreenState();
}

class _MultiBackupRestoreScreenState extends State<MultiBackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BackupInfo> _allBackups = [];
  bool _isLoading = false;
  String? _backupPath;
  Set<DatabaseConfig> _selectedDatabases = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDatabases = widget.backupService.databases.toSet();
    _loadBackups();
    _loadBackupPath();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await widget.backupService.getBackupsList();
    setState(() {
      _allBackups = backups;
      _isLoading = false;
    });
  }

  Future<void> _loadBackupPath() async {
    final path = await widget.backupService.getBackupDirectoryPath();
    setState(() => _backupPath = path);
  }

  List<BackupInfo> get _zipBackups =>
      _allBackups.where((b) => b.isZipBackup).toList();

  List<BackupInfo> get _singleBackups =>
      _allBackups.where((b) => !b.isZipBackup).toList();

  // ============================================
  // BACKUP OPERATIONS
  // ============================================

  Future<void> _backupAllAsZip() async {
    setState(() => _isLoading = true);

    final response = await widget.backupService.backupAllDatabasesAsZip();

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess || response.isPartialSuccess) {
      await _loadBackups();
      if (response.databaseResults != null) {
        _showDatabaseResultsDialog('Backup Results', response.databaseResults!);
      }
    }
  }

  Future<void> _backupSelectedAsZip() async {
    if (_selectedDatabases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one database')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await widget.backupService.backupSelectedDatabasesAsZip(
      _selectedDatabases.toList(),
    );

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess || response.isPartialSuccess) {
      await _loadBackups();
    }
  }

  Future<void> _backupSingleDatabase(DatabaseConfig dbConfig) async {
    setState(() => _isLoading = true);

    final response = await widget.backupService.backupSingleDatabase(dbConfig);

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess) {
      await _loadBackups();
    }
  }

  // ============================================
  // RESTORE OPERATIONS
  // ============================================

  Future<void> _restoreFromZip(BackupInfo backup) async {
    // Show ZIP contents first
    final contents = await widget.backupService.getZipContents(backup.filePath);

    if (!mounted) return;

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore from ZIP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This backup contains:'),
                const SizedBox(height: 8),
                ...contents.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.storage, size: 16),
                        const SizedBox(width: 8),
                        Text(name),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will replace your current databases. Continue?',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    final response = await widget.backupService.restoreAllDatabasesFromZip(
      backup.filePath,
    );

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess || response.isPartialSuccess) {
      if (response.databaseResults != null) {
        _showDatabaseResultsDialog(
          'Restore Results',
          response.databaseResults!,
        );
      }
      _showRestartDialog();
    }
  }

  Future<void> _restoreSingleBackup(BackupInfo backup) async {
    // Try to find matching database config
    DatabaseConfig? targetDb;
    for (final db in widget.backupService.databases) {
      if (backup.fileName.contains(db.name)) {
        targetDb = db;
        break;
      }
    }

    if (targetDb == null) {
      // Let user select target database
      targetDb = await showDialog<DatabaseConfig>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Target Database'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.backupService.databases.map((db) {
              return ListTile(
                title: Text(db.displayName),
                subtitle: Text(db.fileName),
                onTap: () => Navigator.pop(context, db),
              );
            }).toList(),
          ),
        ),
      );

      if (targetDb == null) return;
    }

    final confirm = await _showConfirmDialog(
      'Restore Database',
      'Restore "${backup.fileName}" to ${targetDb.displayName}?\n\nThis will replace your current database.',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    final response = await widget.backupService.restoreSingleDatabase(
      targetDb,
      backup.filePath,
    );

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess) {
      _showRestartDialog();
    }
  }

  Future<void> _restoreFromFilePicker() async {
    setState(() => _isLoading = true);

    final response = await widget.backupService.restoreFromFilePicker();

    setState(() => _isLoading = false);

    _showResultSnackbar(response);

    if (response.isSuccess || response.isPartialSuccess) {
      if (response.databaseResults != null) {
        _showDatabaseResultsDialog(
          'Restore Results',
          response.databaseResults!,
        );
      }
      _showRestartDialog();
    }
  }

  // ============================================
  // DELETE OPERATIONS
  // ============================================

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

  Future<void> _deleteAllBackups() async {
    final confirm = await _showConfirmDialog(
      'Delete All Backups',
      'Are you sure you want to delete all ${_allBackups.length} backups?',
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

  // ============================================
  // HELPER METHODS
  // ============================================

  void _showResultSnackbar(BackupResponse response) {
    if (!mounted) return;

    Color backgroundColor;
    if (response.isSuccess) {
      backgroundColor = Colors.green;
    } else if (response.isPartialSuccess) {
      backgroundColor = Colors.orange;
    } else {
      backgroundColor = Colors.red;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Operation completed'),
        backgroundColor: backgroundColor,
      ),
    );
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

  void _showDatabaseResultsDialog(String title, Map<String, bool> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.entries.map((entry) {
            return ListTile(
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.error,
                color: entry.value ? Colors.green : Colors.red,
              ),
              title: Text(entry.key),
              subtitle: Text(entry.value ? 'Success' : 'Failed'),
            );
          }).toList(),
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

  Future<void> _shareBackup(BackupInfo backup) async {
    await Share.shareXFiles([
      XFile(backup.filePath),
    ], subject: 'Database Backup');
  }

  // ============================================
  // BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          if (_allBackups.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteAllBackups,
              tooltip: 'Delete all backups',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Backup', icon: Icon(Icons.backup)),
            Tab(text: 'ZIP Backups', icon: Icon(Icons.folder_zip)),
            Tab(text: 'Single Backups', icon: Icon(Icons.storage)),
          ],
        ),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    _backupPath!,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Loading Indicator
          if (_isLoading) const LinearProgressIndicator(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBackupTab(),
                _buildZipBackupsTab(),
                _buildSingleBackupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Backup Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_zip, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Full Backup (ZIP)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backup all databases into a single ZIP file',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _backupAllAsZip,
                      icon: const Icon(Icons.backup),
                      label: const Text('Backup All Databases'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Selective Backup Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Selective Backup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select specific databases to backup',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...widget.backupService.databases.map((db) {
                    return CheckboxListTile(
                      title: Text(db.displayName),
                      subtitle: Text(db.fileName),
                      value: _selectedDatabases.contains(db),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedDatabases.add(db);
                          } else {
                            _selectedDatabases.remove(db);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _backupSelectedAsZip,
                      icon: const Icon(Icons.backup),
                      label: Text(
                        'Backup Selected (${_selectedDatabases.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Individual Database Backup Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Individual Backup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backup each database separately',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...widget.backupService.databases.map((db) {
                    return ListTile(
                      leading: const Icon(Icons.storage),
                      title: Text(db.displayName),
                      subtitle: Text(db.fileName),
                      trailing: IconButton(
                        icon: const Icon(Icons.backup, color: Colors.blue),
                        onPressed: _isLoading
                            ? null
                            : () => _backupSingleDatabase(db),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Restore from File Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restore, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Restore from File',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a backup file from your device',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _restoreFromFilePicker,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select Backup File'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZipBackupsTab() {
    return _zipBackups.isEmpty
        ? _buildEmptyState('No ZIP backups found')
        : ListView.builder(
            itemCount: _zipBackups.length,
            itemBuilder: (context, index) {
              final backup = _zipBackups[index];
              return _BackupListItem(
                backup: backup,
                onRestore: () => _restoreFromZip(backup),
                onDelete: () => _deleteBackup(backup),
                onShare: () => _shareBackup(backup),
                isZip: true,
              );
            },
          );
  }

  Widget _buildSingleBackupsTab() {
    return _singleBackups.isEmpty
        ? _buildEmptyState('No single database backups found')
        : ListView.builder(
            itemCount: _singleBackups.length,
            itemBuilder: (context, index) {
              final backup = _singleBackups[index];
              return _BackupListItem(
                backup: backup,
                onRestore: () => _restoreSingleBackup(backup),
                onDelete: () => _deleteBackup(backup),
                onShare: () => _shareBackup(backup),
                isZip: false,
              );
            },
          );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadBackups,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
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
  final bool isZip;

  const _BackupListItem({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
    required this.onShare,
    required this.isZip,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isZip ? Colors.blue.shade100 : Colors.green.shade100,
          child: Icon(
            isZip ? Icons.folder_zip : Icons.storage,
            color: isZip ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          backup.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${dateFormat.format(backup.createdAt)} • ${backup.formattedSize}',
          style: const TextStyle(fontSize: 12),
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

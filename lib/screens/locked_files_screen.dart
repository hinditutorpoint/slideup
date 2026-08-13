import 'dart:io';
import 'package:flutter/material.dart';
import '../services/security_service.dart';
import 'auth_screen.dart';

/// Displays all files that currently have a per-file password lock applied.
///
/// Users can remove an existing lock by tapping the delete icon and confirming
/// with their active security authentication (Pattern, PIN, Password, or Biometrics).
class LockedFilesScreen extends StatefulWidget {
  const LockedFilesScreen({super.key});

  @override
  State<LockedFilesScreen> createState() => _LockedFilesScreenState();
}

class _LockedFilesScreenState extends State<LockedFilesScreen> {
  late Future<List<String>> _lockedIdsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _lockedIdsFuture = SecurityService.instance.getLockedFileIds();
    if (mounted) setState(() {});
  }

  Future<void> _requestUnlock(String fileId) async {
    final fileLockType =
        await SecurityService.instance.getFileLockType(fileId);
    if (!mounted) return;
    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(
          isSetup: false,
          initialLockType: fileLockType,
        ),
      ),
    );

    if (authenticated == true) {
      final file = File(fileId);
      final dir = Directory(fileId);

      if (await file.exists()) {
        await SecurityService.instance.unlockEntityWithSlock(file);
      } else if (await dir.exists()) {
        await SecurityService.instance.unlockEntityWithSlock(dir);
      } else {
        await SecurityService.instance.removeFileLock(fileId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lock removed & file restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locked Files')),
      body: FutureBuilder<List<String>>(
        future: _lockedIdsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data ?? [];

          if (ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_open_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No locked files',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Files you lock will appear here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final id = ids[index];
              return FutureBuilder<String>(
                future: SecurityService.instance.getOriginalFileName(id),
                builder: (context, nameSnapshot) {
                  final displayName = nameSnapshot.data ?? id;
                  return ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.pink),
                    title: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove lock',
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      onPressed: () => _requestUnlock(id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

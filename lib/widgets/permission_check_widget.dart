// widgets/permission_check_widget.dart
import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class PermissionCheckWidget extends StatefulWidget {
  final String path;
  final Widget child;
  final Widget? noPermissionWidget;
  final VoidCallback? onPermissionDenied;

  const PermissionCheckWidget({
    super.key,
    required this.path,
    required this.child,
    this.noPermissionWidget,
    this.onPermissionDenied,
  });

  @override
  State<PermissionCheckWidget> createState() => _PermissionCheckWidgetState();
}

class _PermissionCheckWidgetState extends State<PermissionCheckWidget> {
  bool? _hasPermission;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void didUpdateWidget(PermissionCheckWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);

    final hasPermission = await PermissionService.instance.isPathWritable(
      widget.path,
    );

    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _isChecking = false;
      });

      if (!hasPermission && widget.onPermissionDenied != null) {
        widget.onPermissionDenied!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasPermission == true) {
      return widget.child;
    }

    return widget.noPermissionWidget ?? _buildDefaultNoPermissionWidget();
  }

  Widget _buildDefaultNoPermissionWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'No Write Permission',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have permission to modify files in this location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await PermissionService.instance.requestPermissions();
                _checkPermission();
              },
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => PermissionService.instance.openAppSettings(),
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

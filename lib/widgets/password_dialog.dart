import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  final String fileName;

  const PasswordDialog({super.key, required this.fileName});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isValidating = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Text('Protected Content'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This file is password protected:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            widget.fileName,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            onSubmitted: (_) => _validatePassword(),
          ),
          if (_isValidating)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validatePassword,
          child: const Text('Unlock'),
        ),
      ],
    );
  }

  Future<void> _validatePassword() async {
    setState(() => _isValidating = true);

    // Simulate password validation
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isValidating = false);

      // Return password for validation
      Navigator.pop(context, _passwordController.text);
    }
  }
}

Future<String?> showPasswordDialog(BuildContext context, String fileName) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PasswordDialog(fileName: fileName),
  );
}

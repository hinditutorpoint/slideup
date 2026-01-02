import 'package:flutter/material.dart';
import '../services/security_service.dart';

class AuthScreen extends StatefulWidget {
  final bool isSetup;

  const AuthScreen({super.key, required this.isSetup});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      _showError('Please enter password');
      return;
    }

    if (widget.isSetup) {
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        _showError('Passwords do not match');
        return;
      }

      if (password.length < 4) {
        _showError('Password must be at least 4 characters');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isSetup) {
        await SecurityService.instance.setAppPassword(password);
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final isValid = await SecurityService.instance.verifyAppPassword(
          password,
        );
        if (isValid) {
          Navigator.pop(context, true);
        } else {
          _showError('Invalid password');
        }
      }
    } catch (e) {
      _showError('Authentication failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (widget.isSetup) return;

    setState(() => _isLoading = true);

    final authenticated = await SecurityService.instance
        .authenticateWithBiometric();

    setState(() => _isLoading = false);

    if (authenticated) {
      Navigator.pop(context, true);
    } else {
      _showError('Biometric authentication failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 80, color: Colors.white),
                  const SizedBox(height: 32),
                  Text(
                    widget.isSetup ? 'Setup Password' : 'Enter Password',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isSetup
                        ? 'Create a password to protect your app'
                        : 'Enter your password to continue',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                          onSubmitted: (_) =>
                              widget.isSetup ? null : _authenticate(),
                        ),
                        if (widget.isSetup) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  );
                                },
                              ),
                            ),
                            onSubmitted: (_) => _authenticate(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _authenticate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.isSetup
                                        ? 'Create Password'
                                        : 'Unlock',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        if (!widget.isSetup) ...[
                          const SizedBox(height: 16),
                          FutureBuilder<bool>(
                            future: SecurityService.instance.canUseBiometric(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return TextButton.icon(
                                  onPressed: _authenticateWithBiometric,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Use Biometric'),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!widget.isSetup) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

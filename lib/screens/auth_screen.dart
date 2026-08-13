import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../widgets/pattern_lock_widget.dart';
import '../widgets/pin_lock_widget.dart';

class AuthScreen extends StatefulWidget {
  final bool isSetup;
  final AppLockType? initialLockType;

  const AuthScreen({
    super.key,
    required this.isSetup,
    this.initialLockType,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppLockType _lockType = AppLockType.password;
  bool _isLoading = false;
  bool _isError = false;
  String _errorMessage = '';

  // Setup flow state
  int _setupStep = 1; // 1 = initial draw/input, 2 = confirm draw/input
  List<int>? _firstPattern;
  String? _firstPin;

  // Password controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Biometric state
  bool _canUseBiometric = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _initAuthScreen();
  }

  Future<void> _initAuthScreen() async {
    final canBio = await SecurityService.instance.canUseBiometric();
    final bioEnabled = await SecurityService.instance.isBiometricEnabled();

    AppLockType currentType;
    if (widget.initialLockType != null) {
      currentType = widget.initialLockType!;
    } else {
      currentType = await SecurityService.instance.getAppLockType();
    }

    if (mounted) {
      setState(() {
        _canUseBiometric = canBio;
        _biometricEnabled = bioEnabled;
        _lockType = currentType;
      });

      // Auto-trigger biometric on unlock if enabled
      if (!widget.isSetup && canBio && bioEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometric();
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_isError) {
      setState(() {
        _isError = false;
        _errorMessage = '';
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _isError = true;
      _errorMessage = message;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- BIOMETRIC AUTH ---
  Future<void> _authenticateWithBiometric() async {
    if (widget.isSetup) return;

    setState(() => _isLoading = true);
    final authenticated =
        await SecurityService.instance.authenticateWithBiometric();
    setState(() => _isLoading = false);

    if (authenticated && mounted) {
      Navigator.pop(context, true);
    }
  }

  // --- PASSWORD AUTH ---
  Future<void> _handlePasswordAuth() async {
    _clearError();
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
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final isValid =
            await SecurityService.instance.verifyAppPassword(password);
        if (isValid && mounted) {
          Navigator.pop(context, true);
        } else {
          _showError('Incorrect password');
        }
      }
    } catch (e) {
      _showError('Authentication failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PIN AUTH ---
  Future<void> _handlePinComplete(String pin) async {
    _clearError();

    if (widget.isSetup) {
      if (_setupStep == 1) {
        setState(() {
          _firstPin = pin;
          _setupStep = 2;
        });
      } else {
        if (pin == _firstPin) {
          setState(() => _isLoading = true);
          await SecurityService.instance.setAppPin(pin);
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          _showError('PINs do not match. Try again.');
          setState(() {
            _setupStep = 1;
            _firstPin = null;
          });
        }
      }
    } else {
      setState(() => _isLoading = true);
      final isValid = await SecurityService.instance.verifyAppPin(pin);
      if (isValid && mounted) {
        Navigator.pop(context, true);
      } else {
        _showError('Incorrect PIN');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PATTERN AUTH ---
  Future<void> _handlePatternComplete(List<int> pattern) async {
    _clearError();

    if (pattern.length < 4) {
      _showError('Connect at least 4 dots');
      return;
    }

    if (widget.isSetup) {
      if (_setupStep == 1) {
        setState(() {
          _firstPattern = pattern;
          _setupStep = 2;
        });
      } else {
        if (_listEquals(pattern, _firstPattern)) {
          setState(() => _isLoading = true);
          await SecurityService.instance.setAppPattern(pattern);
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          _showError('Patterns do not match. Try again.');
          setState(() {
            _setupStep = 1;
            _firstPattern = null;
          });
        }
      }
    } else {
      setState(() => _isLoading = true);
      final isValid = await SecurityService.instance.verifyAppPattern(pattern);
      if (isValid && mounted) {
        Navigator.pop(context, true);
      } else {
        _showError('Incorrect pattern');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isSetup,
      child: Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock Header Icon & Title
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Lock Mode Switcher Tabs (Setup Mode only)
                    if (widget.isSetup) _buildLockTypeSelector(),

                    const SizedBox(height: 20),

                    // Authentication Input Body
                    Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_lockType == AppLockType.pattern)
                            _buildPatternSection(),
                          if (_lockType == AppLockType.pin) _buildPinSection(),
                          if (_lockType == AppLockType.password)
                            _buildPasswordSection(),

                          if (_isLoading) ...[
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(color: Colors.white),
                          ],
                        ],
                      ),
                    ),

                    // Biometric Option Button (Unlock Mode)
                    if (!widget.isSetup &&
                        _canUseBiometric &&
                        _biometricEnabled) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _authenticateWithBiometric,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: const Icon(Icons.fingerprint, size: 24),
                        label: const Text('Unlock with Biometrics'),
                      ),
                    ],

                    // Forgot Password / Credential Button
                    if (!widget.isSetup) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _handleForgotCredential,
                        child: const Text(
                          'Forgot Password / Reset Lock?',
                          style: TextStyle(
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleForgotCredential() async {
    final hasQuestion = await SecurityService.instance.hasSecurityQuestion();

    if (!mounted) return;

    if (hasQuestion) {
      final question = await SecurityService.instance.getSecurityQuestion();
      if (!mounted) return;
      _showSecurityQuestionDialog(question ?? 'Security Question');
    } else if (_canUseBiometric && _biometricEnabled) {
      final bioSuccess =
          await SecurityService.instance.authenticateWithBiometric();
      if (bioSuccess && mounted) {
        _showResetConfirmationDialog();
      }
    } else {
      _showResetInfoDialog();
    }
  }

  void _showSecurityQuestionDialog(String question) {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset App Lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Answer your security question to reset your lock:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                question,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your Answer',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _verifyQuestionAnswer(ctx, answerController.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _verifyQuestionAnswer(ctx, answerController.text),
            child: const Text('Verify & Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyQuestionAnswer(
      BuildContext dialogContext, String answer) async {
    if (answer.trim().isEmpty) return;

    final isValid =
        await SecurityService.instance.verifySecurityAnswer(answer);
    if (!mounted || !dialogContext.mounted) return;

    if (isValid) {
      Navigator.pop(dialogContext);
      await SecurityService.instance.removeAppLock();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App lock reset successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('Incorrect answer. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Biometric Verified'),
        content: const Text(
          'Biometric authentication succeeded. Would you like to reset your App Lock credentials now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SecurityService.instance.removeAppLock();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App lock has been reset'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context, true);
            },
            child: const Text('Reset Lock'),
          ),
        ],
      ),
    );
  }

  void _showResetInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot Password / Lock?'),
        content: const Text(
          'To recover access:\n\n'
          '• If Biometrics is enabled, use "Unlock with Biometrics".\n'
          '• You can set up a Security Question in Settings -> Security for instant recovery.\n'
          '• You can also change or remove your lock anytime from Settings after authenticating.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    IconData headerIcon;
    switch (_lockType) {
      case AppLockType.pattern:
        headerIcon = Icons.pattern;
        break;
      case AppLockType.pin:
        headerIcon = Icons.pin;
        break;
      case AppLockType.password:
        headerIcon = Icons.lock_outline;
        break;
    }

    String title;
    String subtitle;

    if (widget.isSetup) {
      if (_setupStep == 1) {
        title = 'Set ${_lockType.displayName}';
        subtitle = 'Choose a secure ${_lockType.displayName.toLowerCase()} to protect your app';
      } else {
        title = 'Confirm ${_lockType.displayName}';
        subtitle = 'Re-enter your ${_lockType.displayName.toLowerCase()} to confirm';
      }
    } else {
      title = 'Enter ${_lockType.displayName}';
      subtitle = 'Authenticate to access Slideup';
    }

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white30, width: 2),
          ),
          child: Icon(headerIcon, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLockTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectorTab(AppLockType.pattern, Icons.gesture, 'Pattern'),
          _buildSelectorTab(AppLockType.pin, Icons.pin, 'PIN'),
          _buildSelectorTab(AppLockType.password, Icons.password, 'Password'),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(AppLockType type, IconData icon, String label) {
    final isSelected = _lockType == type;
    return GestureDetector(
      onTap: () {
        if (_lockType != type) {
          setState(() {
            _lockType = type;
            _setupStep = 1;
            _firstPattern = null;
            _firstPin = null;
            _isError = false;
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternSection() {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PatternLockWidget(
            isError: _isError,
            errorMessage: _errorMessage,
            activeColor: Colors.white,
            errorColor: Colors.redAccent,
            onStarted: _clearError,
            onPatternComplete: _handlePatternComplete,
          ),
        ),
        if (widget.isSetup && _setupStep == 2) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _setupStep = 1;
                _firstPattern = null;
                _isError = false;
              });
            },
            child: const Text(
              'Reset Pattern',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPinSection() {
    return Column(
      children: [
        PinLockWidget(
          pinLength: 4,
          isError: _isError,
          canUseBiometric: !widget.isSetup && _canUseBiometric && _biometricEnabled,
          onBiometricTap: _authenticateWithBiometric,
          onPinComplete: _handlePinComplete,
        ),
        if (widget.isSetup && _setupStep == 2) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _setupStep = 1;
                _firstPin = null;
                _isError = false;
              });
            },
            child: const Text(
              'Reset PIN',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      children: [
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.lock, color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white38),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          onSubmitted: (_) => widget.isSetup ? null : _handlePasswordAuth(),
        ),
        if (widget.isSetup) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white38),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
              ),
            ),
            onSubmitted: (_) => _handlePasswordAuth(),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.isSetup ? 'Save Password' : 'Unlock',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

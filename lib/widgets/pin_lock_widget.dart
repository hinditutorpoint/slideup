import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinLockWidget extends StatefulWidget {
  final int pinLength;
  final Function(String pin) onPinComplete;
  final VoidCallback? onBiometricTap;
  final bool canUseBiometric;
  final bool isError;

  const PinLockWidget({
    super.key,
    this.pinLength = 4,
    required this.onPinComplete,
    this.onBiometricTap,
    this.canUseBiometric = false,
    this.isError = false,
  });

  @override
  State<PinLockWidget> createState() => _PinLockWidgetState();
}

class _PinLockWidgetState extends State<PinLockWidget>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void didUpdateWidget(covariant PinLockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      _shakeController.forward(from: 0.0);
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= widget.pinLength) return;

    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == widget.pinLength) {
      widget.onPinComplete(_enteredPin);
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void resetPin() {
    setState(() {
      _enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Dot Indicators
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isError
                      ? Colors.red
                      : (isFilled
                          ? (theme.primaryColorLight == Colors.white
                              ? Colors.white
                              : theme.primaryColor)
                          : Colors.white24),
                  border: Border.all(
                    color: widget.isError ? Colors.red : Colors.white70,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 36),

        // Keypad Grid 3x4
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            children: [
              _buildRow(['1', '2', '3']),
              const SizedBox(height: 16),
              _buildRow(['4', '5', '6']),
              const SizedBox(height: 16),
              _buildRow(['7', '8', '9']),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Biometric or Empty Button
                  widget.canUseBiometric && widget.onBiometricTap != null
                      ? _buildKeypadButton(
                          child: const Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 28,
                          ),
                          onTap: widget.onBiometricTap,
                        )
                      : const SizedBox(width: 64, height: 64),
                  _buildDigitButton('0'),
                  _buildKeypadButton(
                    child: const Icon(
                      Icons.backspace_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onTap: _onBackspacePressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return _buildKeypadButton(
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      onTap: () => _onDigitPressed(digit),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

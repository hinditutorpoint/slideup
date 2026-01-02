import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GoToPageDialog extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageSelected;

  const GoToPageDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  State<GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<GoToPageDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.currentPage + 1).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndGo() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorText = 'Please enter a page number';
      });
      return;
    }

    final page = int.tryParse(text);
    if (page == null) {
      setState(() {
        _errorText = 'Invalid number';
      });
      return;
    }

    if (page < 1 || page > widget.totalPages) {
      setState(() {
        _errorText = 'Page must be between 1 and ${widget.totalPages}';
      });
      return;
    }

    Navigator.pop(context);
    widget.onPageSelected(page - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: Theme.of(context).primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Go to Page'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter page number (1 - ${widget.totalPages})',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '1',
              errorText: _errorText,
              filled: true,
              fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) {
              if (_errorText != null) {
                setState(() {
                  _errorText = null;
                });
              }
            },
            onSubmitted: (_) => _validateAndGo(),
          ),

          // Quick navigation
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickNavButton(
                  label: 'First',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPageSelected(0);
                  },
                ),
                const SizedBox(width: 8),
                _QuickNavButton(
                  label: '25%',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPageSelected((widget.totalPages * 0.25).floor());
                  },
                ),
                const SizedBox(width: 8),
                _QuickNavButton(
                  label: '50%',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPageSelected((widget.totalPages * 0.5).floor());
                  },
                ),
                const SizedBox(width: 8),
                _QuickNavButton(
                  label: '75%',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPageSelected((widget.totalPages * 0.75).floor());
                  },
                ),
                const SizedBox(width: 8),
                _QuickNavButton(
                  label: 'Last',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPageSelected(widget.totalPages - 1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validateAndGo,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Go'),
        ),
      ],
    );
  }
}

class _QuickNavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickNavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

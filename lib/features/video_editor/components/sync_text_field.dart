import 'package:flutter/material.dart';

class SyncTextField extends StatefulWidget {
  final String text;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;

  const SyncTextField({
    super.key,
    required this.text,
    this.onChanged,
    this.onSubmitted,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  State<SyncTextField> createState() => _SyncTextFieldState();
}

class _SyncTextFieldState extends State<SyncTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(SyncTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      final selection = _controller.selection;
      _controller.text = widget.text;
      if (selection.isValid && selection.end <= widget.text.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      style: widget.style,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

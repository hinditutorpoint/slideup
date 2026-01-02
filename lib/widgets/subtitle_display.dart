import 'package:flutter/material.dart';

class SubtitleDisplay extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final List<Shadow>? shadows;
  final TextAlign textAlign;
  final double? fontSize;
  final Color? textColor;
  final FontWeight? fontWeight;

  const SubtitleDisplay({
    super.key,
    required this.text,
    this.style,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.shadows,
    this.textAlign = TextAlign.center,
    this.fontSize,
    this.textColor,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.8),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style:
            style ??
            TextStyle(
              color: textColor ?? Colors.white,
              fontSize: fontSize ?? 16,
              fontWeight: fontWeight ?? FontWeight.w600,
              shadows:
                  shadows ??
                  [
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
            ),
      ),
    );
  }
}

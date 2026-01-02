import 'package:flutter/material.dart';

/// Screen size breakpoints
class ScreenBreakpoints {
  static const double small = 320;
  static const double medium = 360;
  static const double large = 600;
  static const double extraLarge = 900;
}

/// Responsive helper extension
extension ResponsiveExtension on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  EdgeInsets get safeArea => MediaQuery.of(this).padding;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  bool get isSmallScreen => screenWidth < ScreenBreakpoints.medium;
  bool get isMediumScreen =>
      screenWidth >= ScreenBreakpoints.medium &&
      screenWidth < ScreenBreakpoints.large;
  bool get isLargeScreen => screenWidth >= ScreenBreakpoints.large;
  bool get isExtraLargeScreen => screenWidth >= ScreenBreakpoints.extraLarge;

  /// Get responsive value based on screen size
  T responsive<T>({required T small, T? medium, T? large, T? extraLarge}) {
    if (isExtraLargeScreen) return extraLarge ?? large ?? medium ?? small;
    if (isLargeScreen) return large ?? medium ?? small;
    if (isMediumScreen) return medium ?? small;
    return small;
  }

  /// Get scale factor for fonts
  double get fontScale {
    if (isSmallScreen) return 0.85;
    if (isLargeScreen) return 1.1;
    if (isExtraLargeScreen) return 1.2;
    return 1.0;
  }

  /// Get spacing scale
  double get spacingScale {
    if (isSmallScreen) return 0.8;
    if (isLargeScreen) return 1.2;
    if (isExtraLargeScreen) return 1.4;
    return 1.0;
  }
}

/// Responsive padding widget
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? small;
  final EdgeInsets? medium;
  final EdgeInsets? large;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.small,
    this.medium,
    this.large,
  });

  @override
  Widget build(BuildContext context) {
    final padding = context.responsive<EdgeInsets>(
      small: small ?? const EdgeInsets.all(12),
      medium: medium ?? const EdgeInsets.all(16),
      large: large ?? const EdgeInsets.all(24),
    );

    return Padding(padding: padding, child: child);
  }
}

/// Responsive sized box
class ResponsiveGap extends StatelessWidget {
  final double? smallHeight;
  final double? mediumHeight;
  final double? largeHeight;
  final double? smallWidth;
  final double? mediumWidth;
  final double? largeWidth;

  const ResponsiveGap({
    super.key,
    this.smallHeight,
    this.mediumHeight,
    this.largeHeight,
    this.smallWidth,
    this.mediumWidth,
    this.largeWidth,
  });

  const ResponsiveGap.vertical({
    super.key,
    double small = 8,
    double? medium,
    double? large,
  }) : smallHeight = small,
       mediumHeight = medium,
       largeHeight = large,
       smallWidth = null,
       mediumWidth = null,
       largeWidth = null;

  const ResponsiveGap.horizontal({
    super.key,
    double small = 8,
    double? medium,
    double? large,
  }) : smallWidth = small,
       mediumWidth = medium,
       largeWidth = large,
       smallHeight = null,
       mediumHeight = null,
       largeHeight = null;

  @override
  Widget build(BuildContext context) {
    final height = smallHeight != null
        ? context.responsive<double>(
            small: smallHeight!,
            medium: mediumHeight,
            large: largeHeight,
          )
        : null;

    final width = smallWidth != null
        ? context.responsive<double>(
            small: smallWidth!,
            medium: mediumWidth,
            large: largeWidth,
          )
        : null;

    return SizedBox(height: height, width: width);
  }
}

/// Responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Adaptive icon size based on screen
class AdaptiveIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? smallSize;
  final double? mediumSize;
  final double? largeSize;

  const AdaptiveIcon(
    this.icon, {
    super.key,
    this.color,
    this.smallSize = 20,
    this.mediumSize = 24,
    this.largeSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final size = context.responsive<double>(
      small: smallSize!,
      medium: mediumSize,
      large: largeSize,
    );

    return Icon(icon, size: size, color: color);
  }
}

/// Adaptive text that scales with screen size
class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double? smallSize;
  final double? mediumSize;
  final double? largeSize;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.smallSize = 14,
    this.mediumSize = 16,
    this.largeSize = 18,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = context.responsive<double>(
      small: smallSize!,
      medium: mediumSize,
      large: largeSize,
    );

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

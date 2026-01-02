import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color textColor;
  final Color primaryColor;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.textColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Page number
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${currentPage + 1} / $totalPages',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Progress percentage
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact page indicator for small screens
class CompactPageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color textColor;
  final Color primaryColor;

  const CompactPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.textColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${currentPage + 1}/$totalPages',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: textColor.withValues(alpha: 0.2),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linear progress indicator for page progress
class PageProgressBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;
  final double height;

  const PageProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.activeColor,
    required this.inactiveColor,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: inactiveColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: activeColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

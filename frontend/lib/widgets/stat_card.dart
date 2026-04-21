// lib/widgets/stat_card.dart
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String highlight;
  final Color? color;

  const StatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.highlight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Colors.white;
    final isPrimary = color != null;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: isPrimary ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: isPrimary ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            highlight,
            style: textTheme.headlineSmall?.copyWith(
              color: isPrimary ? Colors.white : const Color(0xFF22A45D),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

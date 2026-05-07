import 'package:flutter/material.dart';

class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({required this.message, this.icon = Icons.insights_outlined, super.key});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    return SizedBox(
      height: 160,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: style?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

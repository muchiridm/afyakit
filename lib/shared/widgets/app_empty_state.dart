import 'package:flutter/material.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.info_outline,
    this.maxWidth = 420,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  final IconData icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44),
              const SizedBox(height: AppShape.gap12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

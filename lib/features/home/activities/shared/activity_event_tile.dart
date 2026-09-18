// lib/core/home/activities/shared/activity_event_tile.dart

import 'package:flutter/material.dart';

class ActivityEventTile extends StatelessWidget {
  const ActivityEventTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.onTap,
    this.statusLabel,
    this.statusColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String timestamp;
  final VoidCallback? onTap;

  final String? statusLabel;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final String? cleanStatus = statusLabel?.trim();
    final bool hasStatus = cleanStatus != null && cleanStatus.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 4),

                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),

                  const SizedBox(height: 4),

                  Text(
                    timestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (hasStatus) ...[
              const SizedBox(width: 12),
              _StatusPill(
                label: cleanStatus,
                color: statusColor ?? Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

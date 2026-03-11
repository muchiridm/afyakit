// lib/core/home/widgets/latest_activity_panel.dart

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class LatestActivityPanel extends StatelessWidget {
  const LatestActivityPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.loading,
    required this.hasError,
    required this.entries,
    this.emptyText = 'No recent activity yet.',
    this.maxItems = 5,
  });

  final String title;
  final IconData icon;

  final bool loading;
  final bool hasError;
  final List<ActivityEntry> entries;

  final String emptyText;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppCard(
        title: title,
        icon: icon,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasError) {
      return AppCard(
        title: title,
        icon: icon,
        child: const Text(
          'Could not load activity.',
          style: TextStyle(fontSize: 12, color: Colors.redAccent),
        ),
      );
    }

    final latest = entries
        .sorted((a, b) => b.date.compareTo(a.date))
        .take(maxItems)
        .toList(growable: false);

    if (latest.isEmpty) {
      return AppCard(
        title: title,
        icon: icon,
        child: Text(emptyText, style: const TextStyle(fontSize: 12)),
      );
    }

    return AppCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (int i = 0; i < latest.length; i++) ...[
            latest[i].widget,
            if (i != latest.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: AppShape.gap8),
                child: Divider(
                  height: AppShape.gap16,
                  thickness: 1,
                  color: AppShape.hairline(
                    Theme.of(context),
                    opacity: 0.20,
                  ).color,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

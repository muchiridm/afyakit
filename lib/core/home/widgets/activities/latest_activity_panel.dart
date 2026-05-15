// lib/core/home/widgets/activities/latest_activity_panel.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

class LatestActivityPanel extends StatelessWidget {
  const LatestActivityPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.loading,
    required this.hasError,
    required this.entries,
    this.emptyText = 'No recent activity yet.',
    this.errorText = 'Could not load activity.',
    this.maxItems = 5,
    this.showTitle = true,
  });

  final String title;
  final IconData icon;

  final bool loading;
  final bool hasError;
  final List<ActivityEntry> entries;

  final String emptyText;
  final String errorText;
  final int maxItems;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final cardTitle = showTitle ? title : null;
    final cardIcon = showTitle ? icon : null;

    if (loading) {
      return AppCard(
        title: cardTitle,
        icon: cardIcon,
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
        title: cardTitle,
        icon: cardIcon,
        child: Text(
          errorText,
          style: const TextStyle(fontSize: 12, color: Colors.redAccent),
        ),
      );
    }

    final latest = entries
        .sorted((a, b) => b.date.compareTo(a.date))
        .take(maxItems)
        .toList(growable: false);

    if (latest.isEmpty) {
      return AppCard(
        title: cardTitle,
        icon: cardIcon,
        child: Text(emptyText, style: const TextStyle(fontSize: 12)),
      );
    }

    return AppCard(
      title: cardTitle,
      icon: cardIcon,
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

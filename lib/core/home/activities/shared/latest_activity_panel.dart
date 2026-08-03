// lib/core/home/activities/shared/latest_activity_panel.dart

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
    this.onTitleTap,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.loadMoreText = 'Load more',
  });

  final String title;
  final IconData icon;

  final bool loading;
  final bool hasError;
  final List<ActivityEntry> entries;

  final String emptyText;
  final String errorText;

  /// Null means show all currently loaded activity.
  ///
  /// For dashboard previews, use 5 or 10.
  /// For history pages, use null and drive pagination with [onLoadMore].
  final int? maxItems;

  final bool showTitle;

  /// When provided, the panel title becomes clickable.
  final VoidCallback? onTitleTap;

  /// True when the backing history source has another page.
  final bool hasMore;

  /// True while the next page is being loaded.
  final bool loadingMore;

  /// Used by history screens to fetch the next page.
  ///
  /// Dashboard previews should normally leave this null.
  final VoidCallback? onLoadMore;

  final String loadMoreText;

  bool get _useCustomClickableTitle => showTitle && onTitleTap != null;

  bool get _showLoadMore {
    return onLoadMore != null && (hasMore || loadingMore);
  }

  @override
  Widget build(BuildContext context) {
    final cardTitle = showTitle && !_useCustomClickableTitle ? title : null;
    final cardIcon = showTitle && !_useCustomClickableTitle ? icon : null;

    final content = _buildContent(context);

    return AppCard(
      title: cardTitle,
      icon: cardIcon,
      child: _useCustomClickableTitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClickableActivityTitle(
                  title: title,
                  icon: icon,
                  onTap: onTitleTap!,
                ),
                const SizedBox(height: AppShape.gap10),
                content,
              ],
            )
          : content,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading && entries.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (hasError && entries.isEmpty) {
      return Text(
        errorText,
        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
      );
    }

    final sorted = entries
        .sorted((a, b) => b.date.compareTo(a.date))
        .toList(growable: false);

    final visible = maxItems == null
        ? sorted
        : sorted.take(maxItems!).toList(growable: false);

    if (visible.isEmpty) {
      return Text(emptyText, style: const TextStyle(fontSize: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          visible[i].widget,
          if (i != visible.length - 1) _ActivityDivider(context),
        ],
        if (hasError) ...[
          const SizedBox(height: AppShape.gap10),
          Text(
            errorText,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        if (_showLoadMore) ...[
          const SizedBox(height: AppShape.gap10),
          _LoadMoreActivityButton(
            loading: loadingMore,
            label: loadMoreText,
            onPressed: loadingMore ? null : onLoadMore,
          ),
        ],
      ],
    );
  }
}

class _ActivityDivider extends StatelessWidget {
  const _ActivityDivider(this.context);

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Padding(
      padding: const EdgeInsets.only(top: AppShape.gap8),
      child: Divider(
        height: AppShape.gap16,
        thickness: 1,
        color: AppShape.hairline(Theme.of(context), opacity: 0.20).color,
      ),
    );
  }
}

class _LoadMoreActivityButton extends StatelessWidget {
  const _LoadMoreActivityButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded),
        label: Text(loading ? 'Loading…' : label),
      ),
    );
  }
}

class _ClickableActivityTitle extends StatelessWidget {
  const _ClickableActivityTitle({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.tileRadius,
        hoverColor: scheme.primary.withOpacity(0.06),
        splashColor: scheme.primary.withOpacity(0.10),
        highlightColor: scheme.primary.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppShape.gap8,
            horizontal: AppShape.gap8,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppShape.gap8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              Text(
                'View all',
                style: t.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppShape.gap4),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

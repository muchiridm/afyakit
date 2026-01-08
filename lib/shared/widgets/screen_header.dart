// lib/shared/widgets/screen_header.dart

import 'package:flutter/material.dart';
import 'package:afyakit/core/auth_user/widgets/user_badge.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  /// Optional leading widget (e.g. CatalogButton).
  /// If provided, it replaces the default back-button/placeholder.
  final Widget? leading;

  /// Old "bar" styling (surface + bottom border).
  final bool withBackground;
  final bool backgroundFullWidth;

  /// Outer padding inside the header container.
  final EdgeInsets outerPadding;

  final bool showUserBadge;
  final bool shrinkTrailing;
  final double leftMinWidth;
  final bool wrapTrailing;

  /// allow big headers
  final double minHeight;

  /// ✅ NEW: render header in a card (recommended for Home flow)
  final bool asCard;

  /// Card shape controls (match your HomeCard vibe)
  final double cardRadius;

  /// If you want an explicit margin around the card; usually keep zero
  /// and let BaseScreen / parent own spacing.
  final EdgeInsets cardMargin;

  const ScreenHeader(
    this.title, {
    super.key,
    this.onBack,
    this.trailing,
    this.showBack = true,
    this.leading,
    this.withBackground = true,
    this.backgroundFullWidth = true,
    this.outerPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    this.showUserBadge = true,
    this.shrinkTrailing = true,
    this.leftMinWidth = 220,
    this.wrapTrailing = false,
    this.minHeight = 72,

    // ✅ NEW
    this.asCard = false,
    this.cardRadius = 16,
    this.cardMargin = EdgeInsets.zero,
  });

  static const double _shrinkBreakpoint = 540;

  bool get _hasTitle => title.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final narrow = w < _shrinkBreakpoint;

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: outerPadding,
        child: narrow ? _buildNarrow(context) : _buildWide(context),
      ),
    );

    // ✅ Card mode: looks like HomeCard (rounded, no full-bleed bar look)
    if (asCard) {
      return Card(
        elevation: 0,
        margin: cardMargin,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        child: content,
      );
    }

    // Old mode (surface bar)
    if (!withBackground) return content;

    final theme = Theme.of(context);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.35),
            width: 0.5,
          ),
        ),
      ),
      child: content,
    );

    return backgroundFullWidth ? decorated : ClipRRect(child: decorated);
  }

  // Small helper to reuse leading/back logic
  Widget _buildLeadingSlot(BuildContext context) {
    if (leading != null) {
      return leading!;
    }

    if (showBack) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      );
    }

    return const SizedBox(width: 48);
  }

  // ───────────────── narrow
  Widget _buildNarrow(BuildContext context) {
    if (!_hasTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildLeadingSlot(context),
              const Spacer(),
              if (trailing != null) Flexible(child: _buildTrailingCluster()),
            ],
          ),
          const SizedBox(height: 10),
          if (showUserBadge)
            const Align(alignment: Alignment.centerLeft, child: UserBadge()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [_buildLeadingSlot(context), const Spacer()]),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (showUserBadge) const UserBadge(),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }

  // ───────────────── wide
  Widget _buildWide(BuildContext context) {
    if (!_hasTitle) {
      return Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: leftMinWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildLeadingSlot(context)],
            ),
          ),
          const Spacer(),
          Flexible(child: _buildTrailingCluster()),
        ],
      );
    }

    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: leftMinWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_buildLeadingSlot(context)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(child: _buildTrailingCluster()),
      ],
    );
  }

  // ───────────────── trailing
  Widget _buildTrailingCluster() {
    final baseRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUserBadge) const UserBadge(),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );

    if (shrinkTrailing) {
      return Align(
        alignment: Alignment.centerRight,
        child: FittedBox(fit: BoxFit.scaleDown, child: baseRow),
      );
    }

    if (wrapTrailing) {
      return LayoutBuilder(
        builder: (context, c) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: c.maxWidth),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (showUserBadge) const UserBadge(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: Align(alignment: Alignment.centerRight, child: baseRow),
          ),
        );
      },
    );
  }
}

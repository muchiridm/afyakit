// lib/shared/widgets/screen_header.dart
import 'package:afyakit/shared/widgets/screen_header/tenant_brand_lockup.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/core/auth_users/widgets/user_badge.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  final bool showLogo;
  final Widget? logo;
  final double logoHeight;

  final bool withBackground;
  final bool backgroundFullWidth;
  final EdgeInsets outerPadding;

  final bool showUserBadge;
  final bool shrinkTrailing;
  final double leftMinWidth;
  final bool wrapTrailing;

  /// allow big headers
  final double minHeight;

  const ScreenHeader(
    this.title, {
    super.key,
    this.onBack,
    this.trailing,
    this.showBack = true,
    this.showLogo = false,
    this.logo,
    this.logoHeight = 28,
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

  // ───────────────── narrow
  Widget _buildNarrow(BuildContext context) {
    final Widget? brand =
        logo ??
        (showLogo
            ? TenantBrandLockup(
                height: logoHeight,
                showName: _hasTitle ? false : true,
              )
            : null);

    if (!_hasTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: 48),
              if (brand != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Align(alignment: Alignment.centerLeft, child: brand),
                ),
              ],
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
        Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: 48),
            if (brand != null) ...[const SizedBox(width: 10), brand],
            const Spacer(),
          ],
        ),
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
    final Widget? brand =
        logo ?? (showLogo ? TenantBrandLockup(height: logoHeight) : null);

    if (!_hasTitle) {
      return Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: leftMinWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 48),
                if (brand != null) ...[
                  const SizedBox(width: 10),
                  Flexible(child: brand),
                ],
              ],
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
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: 48),
              if (brand != null) ...[
                const SizedBox(width: 10),
                Flexible(child: brand),
              ],
            ],
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

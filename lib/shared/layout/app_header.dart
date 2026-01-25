// lib/shared/layout/app_header.dart
import 'package:flutter/material.dart';
import 'package:afyakit/core/auth_user/widgets/user_badge.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

enum AppHeaderVariant { bar, card, plain }

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.leading,
    this.trailing,
    this.showBack = true,
    this.showUserBadge = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.minHeight = 72,
    this.variant = AppHeaderVariant.bar,
    this.titleStyle,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;

  final bool showBack;
  final bool showUserBadge;

  final EdgeInsets padding;
  final double minHeight;

  final AppHeaderVariant variant;

  /// Optional override (otherwise uses theme.titleLarge)
  final TextStyle? titleStyle;

  static const double _narrowBp = 540;

  bool get _hasTitle => title.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < _narrowBp;

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: narrow ? _buildRow(context, tight: true) : _buildRow(context),
      ),
    );

    switch (variant) {
      case AppHeaderVariant.plain:
        return content;

      case AppHeaderVariant.card:
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: AppShape.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: content,
        );

      case AppHeaderVariant.bar:
        final theme = Theme.of(context);
        return DecoratedBox(
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
    }
  }

  Widget _buildRow(BuildContext context, {bool tight = false}) {
    return Row(
      children: [
        _leadingSlot(context),
        SizedBox(width: tight ? 6 : 10),
        Expanded(child: _title(context)),
        _trailingSlot(),
      ],
    );
  }

  Widget _leadingSlot(BuildContext context) {
    if (leading != null) return leading!;
    if (!showBack) return const SizedBox(width: 48);

    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
    );
  }

  Widget _trailingSlot() {
    if (trailing == null && !showUserBadge) return const SizedBox(width: 48);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUserBadge) const UserBadge(),
        if (trailing != null) ...[
          if (showUserBadge) const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }

  Widget _title(BuildContext context) {
    if (!_hasTitle) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    final style =
        titleStyle ?? t.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

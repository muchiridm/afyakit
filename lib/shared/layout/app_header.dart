// lib/shared/layout/app_header.dart
import 'package:flutter/material.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_badge.dart';
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

  /// How much width we allow for the trailing cluster on narrow screens.
  /// Must be large enough to always show the primary action (e.g. cart),
  /// but small enough to avoid pushing title off-screen.
  static const double _narrowTrailingMaxWidth = 180;

  bool get _hasTitle => title.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < _narrowBp;

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: _buildRow(context, narrow: narrow),
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

  Widget _buildRow(BuildContext context, {required bool narrow}) {
    final gap = narrow ? 6.0 : 10.0;

    return Row(
      children: [
        _leadingSlot(context),
        SizedBox(width: gap),

        // Title takes remaining space
        Expanded(child: _title(context)),

        SizedBox(width: gap),

        // Trailing is always visible; on narrow we keep primary action visible
        // by prioritizing trailing and optionally dropping the badge.
        _trailingSlot(narrow: narrow),
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

  Widget _trailingSlot({required bool narrow}) {
    final empty = (trailing == null && !showUserBadge);
    if (empty) return const SizedBox(width: 48);

    // ✅ Key behavior change:
    // On narrow screens, if there's an explicit trailing action (e.g. cart),
    // we prioritize it by hiding the (often wide) UserBadge.
    final bool effectiveShowBadge =
        showUserBadge && !(narrow && trailing != null);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (effectiveShowBadge) const UserBadge(),
        if (trailing != null) ...[
          if (effectiveShowBadge) const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );

    if (!narrow) return content;

    // Narrow: cap width and allow horizontal scroll as a safety valve.
    // Even if something is too wide, it won't overflow the header row.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _narrowTrailingMaxWidth),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: content,
        ),
      ),
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

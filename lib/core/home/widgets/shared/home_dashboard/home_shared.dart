// lib/core/home/widgets/shared/home_dashboard/home_shared.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/auth_user/widgets/user_badge.dart';
import 'package:afyakit/core/hq/branding/widgets/tenant_brand_logo.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

const double homeDashboardTwoColBreakpoint = 900;
const double homeTopBarWideBreakpoint = 900;
const double homeTopBarMediumBreakpoint = 620;

Widget homeVerticalStack(List<Widget> children, {double gap = AppShape.gap12}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (int i = 0; i < children.length; i++) ...[
        children[i],
        if (i != children.length - 1) SizedBox(height: gap),
      ],
    ],
  );
}

class HomeDashboardTwoColumnLayout extends StatelessWidget {
  const HomeDashboardTwoColumnLayout({
    super.key,
    required this.leading,
    required this.trailing,
    this.breakpoint = homeDashboardTwoColBreakpoint,
    this.gap = AppShape.gap14,
    this.stackedGap = AppShape.gap12,
  });

  /// Left column on wide screens.
  /// Second section on narrow screens.
  final Widget leading;

  /// Right column on wide screens.
  /// First section on narrow screens.
  final Widget trailing;

  final double breakpoint;
  final double gap;
  final double stackedGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= breakpoint;

        if (!twoCol) {
          return homeVerticalStack([trailing, leading], gap: stackedGap);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: leading),
            SizedBox(width: gap),
            Expanded(flex: 1, child: trailing),
          ],
        );
      },
    );
  }
}

class HomeDashboardTopBar extends StatelessWidget {
  const HomeDashboardTopBar({
    super.key,
    required this.title,
    required this.trailing,
    this.fallbackTitle = 'AfyaKit',
    this.trailingMaxWidth = 440,
  });

  final String title;
  final Widget trailing;
  final String fallbackTitle;
  final double trailingMaxWidth;

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.trim().isEmpty ? fallbackTitle : title.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;

          if (width >= homeTopBarWideBreakpoint) {
            return _HomeDashboardTopBarShell(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: UserBadge(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 180),
                    child: TenantBrandLogo(
                      size: TenantBrandLogoSize.large,
                      fallbackLabel: cleanTitle,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: trailingMaxWidth),
                      child: HomeHeaderActionsScroller(child: trailing),
                    ),
                  ),
                ],
              ),
            );
          }

          if (width >= homeTopBarMediumBreakpoint) {
            return _HomeDashboardTopBarShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TenantBrandLogo(
                    size: TenantBrandLogoSize.large,
                    fallbackLabel: cleanTitle,
                  ),
                  const SizedBox(height: AppShape.gap10),
                  Row(
                    children: [
                      const UserBadge(),
                      const SizedBox(width: AppShape.gap12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: HomeHeaderActionsScroller(child: trailing),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return _HomeDashboardTopBarShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TenantBrandLogo(
                  size: TenantBrandLogoSize.large,
                  fallbackLabel: cleanTitle,
                ),
                const SizedBox(height: AppShape.gap8),
                const UserBadge(),
                const SizedBox(height: AppShape.gap10),
                Center(child: HomeHeaderActionsScroller(child: trailing)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HomeHeaderActionsScroller extends StatelessWidget {
  const HomeHeaderActionsScroller({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

class _HomeDashboardTopBarShell extends StatelessWidget {
  const _HomeDashboardTopBarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: child,
    );
  }
}

class HomeHeaderTitle extends StatelessWidget {
  const HomeHeaderTitle(this.title, {super.key, required this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
    );
  }
}

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.centerHeader = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool centerHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: centerHeader
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: AppShape.gap8),
            Text(
              title,
              textAlign: centerHeader ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppShape.gap8),
        child,
      ],
    );
  }
}

class QuietHomePanel extends StatelessWidget {
  const QuietHomePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: 0.84,
      child: Material(
        elevation: 0,
        color: scheme.surface.withOpacity(0.64),
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class HomeActionChip extends StatelessWidget {
  const HomeActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class HomeInfoCard extends StatelessWidget {
  const HomeInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeCatalogSearchHero extends StatefulWidget {
  const HomeCatalogSearchHero({
    super.key,
    required this.onSearch,
    required this.onBrowse,
    this.onSecondaryTap,
    this.secondaryLabel = 'Chat pharmacist',
    this.secondaryIcon = Icons.chat_bubble_outline_rounded,
    this.hintText = 'Search medicines, brands, conditions…',
    this.footerText = 'Browse catalog',
    this.autofocus = false,
  });

  final void Function(String query) onSearch;
  final VoidCallback onBrowse;
  final VoidCallback? onSecondaryTap;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final String hintText;
  final String footerText;
  final bool autofocus;

  @override
  State<HomeCatalogSearchHero> createState() => _HomeCatalogSearchHeroState();
}

class _HomeCatalogSearchHeroState extends State<HomeCatalogSearchHero> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSearch(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 1.5,
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surface,
              child: TextField(
                controller: _c,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.onSecondaryTap != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onSecondaryTap,
                      icon: Icon(widget.secondaryIcon, size: 18),
                      label: Text(widget.secondaryLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onBrowse,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Browse catalog'),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: widget.onBrowse,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Browse catalog'),
              ),
            const SizedBox(height: 6),
            Text(
              widget.footerText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

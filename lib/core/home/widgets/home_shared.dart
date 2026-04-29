import 'package:flutter/material.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

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

  void _submit() => widget.onSearch(_c.text.trim());

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

// lib/shared/widgets/app_bottom_sheet.dart

import 'package:flutter/material.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  double maxWidth = 720,
  double maxHeightFactor = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final MediaQueryData media = MediaQuery.of(sheetContext);
      final ThemeData theme = Theme.of(sheetContext);

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12 + media.viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: media.size.height * maxHeightFactor,
              ),
              child: Material(
                color: theme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                  bottom: Radius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (showDragHandle)
                      const Padding(
                        padding: EdgeInsets.only(top: 10, bottom: 4),
                        child: _SheetDragHandle(),
                      ),
                    Flexible(child: builder(sheetContext)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.trailing,
    this.footer,
    this.busy = false,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget body;
  final Widget? footer;
  final bool busy;
  final bool scrollable;
  final EdgeInsetsGeometry bodyPadding;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: bodyPadding, child: body);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AppBottomSheetHeader(
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          busy: busy,
          onClose: onClose ?? () => Navigator.of(context).maybePop(),
        ),
        const Divider(height: 1),
        Flexible(
          child: scrollable
              ? SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                )
              : content,
        ),
        if (footer != null) ...<Widget>[const Divider(height: 1), footer!],
      ],
    );
  }
}

class _AppBottomSheetHeader extends StatelessWidget {
  const _AppBottomSheetHeader({
    required this.title,
    required this.busy,
    required this.onClose,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            Padding(padding: const EdgeInsets.only(top: 2), child: leading!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!.trim(), style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          IconButton(
            tooltip: 'Close',
            onPressed: busy ? null : onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: colors.onSurfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

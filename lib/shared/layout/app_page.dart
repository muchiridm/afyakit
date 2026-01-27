// lib/shared/layout/app_page.dart

import 'package:flutter/material.dart';
import 'package:afyakit/shared/layout/app_layout.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    this.appBar,
    this.title,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.header,
    required this.body,
    this.footer,

    // FAB (constrained)
    this.fab,
    this.fabAlignment = Alignment.bottomRight,
    this.fabPadding,

    // Layout
    this.scrollable = true,
    this.maxWidth = AppLayout.pageMaxW,
    this.padding = AppLayout.pagePadding,
    this.backgroundColor,
  });

  // App bar options
  final PreferredSizeWidget? appBar;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  // Content
  final Widget? header;
  final Widget body;
  final Widget? footer;

  // FAB
  final Widget? fab;
  final Alignment fabAlignment;
  final EdgeInsets? fabPadding;

  // Layout
  final bool scrollable;
  final double maxWidth;
  final EdgeInsets padding;
  final Color? backgroundColor;

  bool get _useDefaultAppBar =>
      appBar == null && (title?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (header != null) header!, body],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) header!,
              Expanded(child: body),
            ],
          );

    final appBarWidget = _useDefaultAppBar
        ? _DefaultAppBar(
            title: title!,
            showBack: showBack,
            onBack: onBack,
            actions: actions,
            maxWidth: maxWidth,
            padding: padding,
          )
        : appBar;

    final effectiveFabPadding =
        fabPadding ??
        EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBarWidget,
      body: Stack(
        children: [
          // Main content column (centered + constrained)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(padding: padding, child: content),
              ),
            ),
          ),

          // FAB overlay
          if (fab != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: effectiveFabPadding,
                    child: Align(alignment: fabAlignment, child: fab!),
                  ),
                ),
              ),
            ),
        ],
      ),

      // ✅ The only reliable way: WRAP (shrink-wrap height)
      bottomNavigationBar: footer == null
          ? null
          : Material(
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                child: Wrap(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: padding.left,
                          ),
                          child: footer!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DefaultAppBar({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.actions,
    required this.maxWidth,
    required this.padding,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 48),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

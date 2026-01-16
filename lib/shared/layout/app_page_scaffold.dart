// lib/shared/layout/app_page_scaffold.dart

import 'package:flutter/material.dart';
import 'app_layout.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.fab,
    this.bottomOverlay,
    this.topOverlay,
    this.scrollable = false,

    /// Extra breathing room for the anchored FAB (optional).
    this.fabPadding = const EdgeInsets.only(right: 4, bottom: 4),
  });

  final PreferredSizeWidget appBar;
  final Widget body;

  /// Floating action button anchored to the *page* column (not screen edge).
  final Widget? fab;

  /// Optional overlays rendered above the body (inside the padded area).
  final Widget? topOverlay;
  final Widget? bottomOverlay;

  /// If true, wraps [body] in SingleChildScrollView + padding.
  final bool scrollable;

  final EdgeInsets fabPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ✅ Important: do NOT use Scaffold's floatingActionButton,
      // because it anchors to the full screen, not our constrained page.
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.pageMaxW),
            child: Column(
              children: [
                // ✅ constrained app bar
                Material(
                  elevation: 0,
                  color: theme.appBarTheme.backgroundColor,
                  child: appBar,
                ),

                // ✅ page content
                Expanded(
                  child: Padding(
                    padding: AppLayout.pagePadding,
                    child: Stack(
                      children: [
                        // Main content
                        scrollable ? SingleChildScrollView(child: body) : body,

                        // Overlays
                        if (topOverlay != null) topOverlay!,
                        if (bottomOverlay != null) bottomOverlay!,

                        // ✅ FAB anchored to page column bottom-right
                        if (fab != null)
                          Positioned(
                            right: fabPadding.right,
                            bottom: fabPadding.bottom,
                            child: fab!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

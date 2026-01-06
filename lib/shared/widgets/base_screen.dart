// lib/shared/widgets/base_screen.dart

import 'package:flutter/material.dart';

class BaseScreen extends StatelessWidget {
  final Widget body;
  final Widget? header;
  final Widget? footer;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final bool scrollable;
  final double? maxContentWidth;

  /// Body padding (main content)
  final EdgeInsets contentPadding;

  /// Header padding (defaults to none because ScreenHeader already pads itself)
  final EdgeInsets headerPadding;

  /// Footer padding
  final EdgeInsets footerPadding;

  final ScrollController? scrollController;

  /// Layout overrides
  final bool constrainBody;
  final bool constrainHeader;
  final bool constrainFooter;

  /// ✅ NEW:
  /// If true, header is allowed to be full-bleed (span full width).
  /// Useful when the header draws a full-width background but constrains
  /// its *inner content* to [maxContentWidth].
  final bool headerFullBleed;

  const BaseScreen({
    super.key,
    required this.body,
    this.header,
    this.footer,
    this.drawer,
    this.endDrawer,
    this.floatingActionButton,
    this.scrollable = true,
    this.maxContentWidth,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),

    // ✅ IMPORTANT: keep header unpadded by default (ScreenHeader handles it)
    this.headerPadding = EdgeInsets.zero,

    this.footerPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    this.scrollController,
    this.constrainBody = true,
    this.constrainHeader = true,
    this.constrainFooter = true,

    // ✅ NEW default: headers are usually full-bleed on web/desktop
    this.headerFullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget constrainChild(
      Widget child, {
      required bool constrain,
      required EdgeInsets padding,
    }) {
      if (!constrain || maxContentWidth == null) {
        return Padding(padding: padding, child: child);
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final width = screenWidth < maxContentWidth!
          ? screenWidth
          : maxContentWidth!;
      return Center(
        child: Container(width: width, padding: padding, child: child),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // Header
    // ─────────────────────────────────────────────────────────────
    final Widget? headerWidget = header == null
        ? null
        : (headerFullBleed
              // ✅ Full width header; the header itself should handle inner max width alignment.
              ? Padding(padding: headerPadding, child: header!)
              : constrainChild(
                  header!,
                  constrain: constrainHeader,
                  padding: headerPadding,
                ));

    // ─────────────────────────────────────────────────────────────
    // Body
    // ─────────────────────────────────────────────────────────────
    final Widget bodyWidget = constrainChild(
      body,
      constrain: constrainBody,
      padding: contentPadding,
    );

    // ─────────────────────────────────────────────────────────────
    // Footer
    // ─────────────────────────────────────────────────────────────
    final Widget? footerWidget = footer != null
        ? constrainChild(
            footer!,
            constrain: constrainFooter,
            padding: footerPadding,
          )
        : null;

    final Widget scrollableBody = SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (headerWidget != null) headerWidget, bodyWidget],
      ),
    );

    final Widget nonScrollableBody = Column(
      children: [
        if (headerWidget != null) headerWidget,
        Expanded(child: bodyWidget),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: drawer,
      endDrawer: endDrawer,
      body: SafeArea(child: scrollable ? scrollableBody : nonScrollableBody),
      bottomNavigationBar: footerWidget,
      floatingActionButton: floatingActionButton,
    );
  }
}

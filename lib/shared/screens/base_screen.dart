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
  final EdgeInsets contentPadding;
  final ScrollController? scrollController;

  /// Layout overrides
  final bool constrainBody;
  final bool constrainHeader;
  final bool constrainFooter;

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
    this.scrollController,
    this.constrainBody = true,
    this.constrainHeader = true,
    this.constrainFooter = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget constrainChild(Widget child, {required bool constrain}) {
      if (!constrain || maxContentWidth == null) {
        return Padding(padding: contentPadding, child: child);
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final width =
          screenWidth < maxContentWidth! ? screenWidth : maxContentWidth!;
      return Center(
        child: Container(width: width, padding: contentPadding, child: child),
      );
    }

    final Widget? headerWidget =
        header != null
            ? constrainChild(header!, constrain: constrainHeader)
            : null;

    final Widget bodyWidget = constrainChild(body, constrain: constrainBody);

    final Widget? footerWidget =
        footer != null
            ? constrainChild(footer!, constrain: constrainFooter)
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

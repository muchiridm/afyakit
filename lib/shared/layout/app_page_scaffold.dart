import 'package:flutter/material.dart';

/// A simple app scaffold that:
/// - constrains max width
/// - provides SafeArea + padding
/// - optionally scrolls
/// - IMPORTANT: when scrollable == false, it gives the body a bounded height
///   using SizedBox.expand(), so children can safely use Column/Expanded.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.scrollable = true,
    this.maxWidth = 820,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,

    // ✅ Back-compat: your code uses `fab:`
    this.fab,
    this.fabLocation,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool scrollable;
  final double maxWidth;
  final EdgeInsets padding;
  final Color? backgroundColor;

  /// Floating action button (back-compat with existing callers).
  final Widget? fab;

  /// Optional FAB location.
  final FloatingActionButtonLocation? fabLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: fab,
      floatingActionButtonLocation: fabLocation,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: scrollable
                  ? SingleChildScrollView(child: body)
                  : SizedBox.expand(
                      // ✅ Key fix: bounded height so Column/Expanded works.
                      child: body,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

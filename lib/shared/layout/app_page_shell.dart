import 'package:flutter/material.dart';
import 'app_layout.dart';

class AppPageShell extends StatelessWidget {
  const AppPageShell({super.key, required this.child, this.scrollable = true});

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: AppLayout.pagePadding, child: child);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.pageMaxW),
          child: scrollable ? SingleChildScrollView(child: content) : content,
        ),
      ),
    );
  }
}

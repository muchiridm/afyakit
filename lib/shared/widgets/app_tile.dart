import 'package:flutter/material.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.child,
    this.padding = AppShape.tilePad,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: AppShape.tileDecoration(theme),
      child: Padding(padding: padding, child: child),
    );
  }
}

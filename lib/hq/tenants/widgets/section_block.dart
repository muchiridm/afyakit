// lib/hq/tenants/widgets/section_block.dart
import 'package:flutter/material.dart';

class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

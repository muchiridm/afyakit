import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:flutter/material.dart';

class DetailRecordScreen extends StatelessWidget {
  final Widget header;
  final List<Widget> contentSections; // Cards, metadata, etc.
  final List<Widget>? actionButtons;
  final double maxContentWidth;

  const DetailRecordScreen({
    super.key,
    required this.header,
    required this.contentSections,
    this.actionButtons,
    this.maxContentWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      scrollable: true,
      maxContentWidth: maxContentWidth,
      header: header,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...contentSections,
            if (actionButtons != null && actionButtons!.isNotEmpty) ...[
              const Divider(height: 32),
              Wrap(spacing: 12, runSpacing: 12, children: actionButtons!),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

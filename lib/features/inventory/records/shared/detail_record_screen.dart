import 'package:flutter/material.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/layout/app_layout.dart';

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
    this.maxContentWidth = AppLayout.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      scrollable: true,
      maxWidth: maxContentWidth,
      header: header,
      body: Column(
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
    );
  }
}

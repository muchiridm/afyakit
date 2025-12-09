import 'package:flutter/material.dart';

class StockReportHeaderBar extends StatelessWidget {
  final String title;
  final Widget? filters;
  final bool showBack;

  const StockReportHeaderBar({
    super.key,
    required this.title,
    this.filters,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (showBack) const BackButton(),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (showBack)
                const SizedBox(width: 48), // Balance the back button spacing
            ],
          ),
        ),
        if (filters != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: filters!,
          ),
      ],
    );
  }
}

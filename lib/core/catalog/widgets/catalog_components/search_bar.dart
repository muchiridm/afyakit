// lib/core/catalog/widgets/catalog_components/search_bar.dart

import 'package:flutter/material.dart';

class SearchBarField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;

  /// Optional number of results to show just under the bar (right side)
  final int? resultCount;

  const SearchBarField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onChanged,
    this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String? resultsLabel = (resultCount != null)
        ? '${resultCount!} result${resultCount == 1 ? '' : 's'}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 1.5,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'Search brand, strength, form…',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (resultsLabel != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              resultsLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

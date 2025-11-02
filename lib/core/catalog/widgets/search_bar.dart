// lib/core/catalog/public/widgets/_search_bar.dart
import 'package:flutter/material.dart';

class SearchBarField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  const SearchBarField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

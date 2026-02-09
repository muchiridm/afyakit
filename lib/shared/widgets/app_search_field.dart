import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.loading = false,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final String hintText;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final trimmed = controller.text.trim();

    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (trimmed.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: enabled ? onClear : null,
                      icon: const Icon(Icons.clear),
                    )),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

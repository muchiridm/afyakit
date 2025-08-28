import 'package:flutter/material.dart';

/// Reusable text input with optional label
Widget buildField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

/// Required text input with validation
Widget buildRequiredField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '${label.replaceAll("*", "").trim()} is required';
        }
        return null;
      },
    ),
  );
}

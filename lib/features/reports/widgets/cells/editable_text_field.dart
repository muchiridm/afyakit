import 'package:flutter/material.dart';

class EditableTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSubmit;

  const EditableTextField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Text(
        controller.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.teal.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmit,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class EditableChipList extends StatelessWidget {
  final Map<String, String> labelToId;
  final ValueChanged<String>? onRemove;
  final ValueChanged<String>? onAdd;
  final String? hintText;

  const EditableChipList({
    super.key,
    required this.labelToId,
    this.onRemove,
    this.onAdd,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final labels = labelToId.keys.toList();

    final controller = TextEditingController();

    void submit() {
      final text = controller.text.trim();
      if (text.isEmpty) return;

      onAdd?.call(text);
      controller.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              labels
                  .map(
                    (label) => Chip(
                      label: Text(label),
                      onDeleted:
                          onRemove != null
                              ? () => onRemove!(labelToId[label]!)
                              : null,
                    ),
                  )
                  .toList(),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText ?? 'Add value...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: submit, child: const Text('Add')),
            ],
          ),
        ],
      ],
    );
  }
}

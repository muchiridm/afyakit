import 'package:afyakit/features/item_preferences/utils/item_preference_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/item_preferences/item_preferences_controller.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';

class ItemPreferenceAutocompleteField extends ConsumerStatefulWidget {
  final ItemType itemType;
  final ItemPreferenceField preferenceField;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String label;

  const ItemPreferenceAutocompleteField({
    super.key,
    required this.itemType,
    required this.preferenceField,
    required this.onChanged,
    required this.label,
    this.initialValue,
  });

  @override
  ConsumerState<ItemPreferenceAutocompleteField> createState() =>
      _ItemPreferenceAutocompleteFieldState();
}

class _ItemPreferenceAutocompleteFieldState
    extends ConsumerState<ItemPreferenceAutocompleteField> {
  late final TextEditingController _controller;

  PreferenceKey get _preferenceKey =>
      PreferenceKey(widget.itemType, widget.preferenceField);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemPreferenceControllerProvider(_preferenceKey));

    return state.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (suggestions) => _buildAutocomplete(suggestions),
    );
  }

  Widget _buildAutocomplete(List<String> suggestions) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _controller.text),
      optionsBuilder: (textEditingValue) {
        final input = textEditingValue.text.toLowerCase();
        if (input.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(input));
      },
      onSelected: (value) {
        _controller.text = value;
        widget.onChanged(value);
      },
      fieldViewBuilder: (context, textFieldController, focusNode, _) {
        return TextFormField(
          controller: textFieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) {}, // typing triggers suggestions
          onFieldSubmitted: (_) {
            final value = textFieldController.text.trim();
            if (value.isEmpty || suggestions.contains(value)) {
              widget.onChanged(value);
            } else {
              textFieldController.clear();
            }
          },
          onEditingComplete: () {
            final value = textFieldController.text.trim();
            if (!suggestions.contains(value)) {
              textFieldController.clear();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

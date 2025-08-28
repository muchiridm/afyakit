import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/controllers/forms/medication_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/item_preferences/item_preference_autocomplete_field.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/inventory/screens/inventory_editor_components/inventory_field_helpers.dart';
import 'package:afyakit/core/inventory/screens/inventory_editor_components/inventory_form_builder.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';

class MedicationForm extends ConsumerStatefulWidget {
  final MedicationItem? item;

  const MedicationForm({super.key, this.item});

  @override
  ConsumerState<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends ConsumerState<MedicationForm> {
  final _formKey = GlobalKey<FormState>();

  final _generic = TextEditingController();
  final _brand = TextEditingController();
  final _strength = TextEditingController();
  final _size = TextEditingController();
  final _formulation = TextEditingController();
  final _route = TextEditingController();
  final _packSize = TextEditingController();
  final _group = TextEditingController();
  final _reorder = TextEditingController();
  final _proposed = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) _populate(widget.item!);
  }

  @override
  void dispose() {
    for (final c in [
      _generic,
      _brand,
      _strength,
      _size,
      _formulation,
      _route,
      _packSize,
      _group,
      _reorder,
      _proposed,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InventoryFormBuilder(
      formKey: _formKey,
      onSubmit: _submit,
      buttonLabel: widget.item == null
          ? 'Save Medication'
          : 'Update Medication',
      fields: _buildFields(),
    );
  }

  List<Widget> _buildFields() => [
    buildRequiredField(_generic, 'Generic Name *'),
    buildField(_brand, 'Brand Name (optional)'),
    buildField(_strength, 'Strength (optional)'),
    buildField(_size, 'Size (optional)'),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.medication,
      preferenceField: ItemPreferenceField.formulation,
      label: 'Formulation (optional)',
      initialValue: _formulation.text,
      onChanged: (val) => _formulation.text = val,
    ),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.medication,
      preferenceField: ItemPreferenceField.route,
      label: 'Route (comma separated)',
      initialValue: _route.text,
      onChanged: (val) => _route.text = val,
    ),
    const SizedBox(height: 16),
    buildField(_packSize, 'Pack Size (optional)'),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.medication,
      preferenceField: ItemPreferenceField.group,
      label: 'Group *',
      initialValue: _group.text,
      onChanged: (val) => _group.text = val,
    ),
    const SizedBox(height: 16),
    buildField(_reorder, 'Reorder Level (optional)'),
    buildField(_proposed, 'Proposed Order (optional)'),
  ];

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isNew = widget.item == null;
    final id = isNew ? const Uuid().v4() : widget.item!.id;

    final data = {
      'id': id,
      'itemType': ItemType.medication.name,
      'name': _generic.text.trim(),
      'brandName': _nullable(_brand),
      'strength': _nullable(_strength),
      'size': _nullable(_size),
      'formulation': _nullable(_formulation),
      'route': _list(_route),
      'packSize': _nullable(_packSize),
      'group': _group.text.trim(),
      'reorderLevel': _int(_reorder),
      'proposedOrder': _int(_proposed),
    };

    final item = MedicationItem.fromMap(id!, data);
    final controller = ref.read(medicationControllerProvider);

    try {
      if (isNew) {
        await controller.create(item);
      } else {
        await controller.update(item);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      SnackService.showError('Submission failed: ${e.toString()}');
    }
  }

  void _populate(MedicationItem item) {
    _generic.text = item.name;
    _brand.text = item.brandName ?? '';
    _strength.text = item.strength ?? '';
    _size.text = item.size ?? '';
    _formulation.text = item.formulation ?? '';
    _route.text = item.route?.join(', ') ?? '';
    _packSize.text = item.packSize ?? '';
    _group.text = item.group;
    _reorder.text = item.reorderLevel?.toString() ?? '';
    _proposed.text = item.proposedOrder?.toString() ?? '';
  }

  String? _nullable(TextEditingController c) {
    final val = c.text.trim();
    return val.isEmpty ? null : val;
  }

  List<String>? _list(TextEditingController c) {
    final val = c.text.trim();
    if (val.isEmpty) return null;

    final parsed = val
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return parsed.isEmpty ? null : parsed;
  }

  int? _int(TextEditingController c) {
    final val = c.text.trim();
    if (val.isEmpty) return null; // ✅ Truly empty field
    return int.tryParse(val); // ✅ Includes 0, 1, 999...
  }
}

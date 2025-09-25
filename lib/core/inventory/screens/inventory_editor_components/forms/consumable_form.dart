import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/controllers/forms/consumable_controller.dart';
import 'package:afyakit/core/item_preferences/widgets/item_preference_autocomplete_field.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/screens/inventory_editor_components/inventory_field_helpers.dart';
import 'package:afyakit/core/inventory/screens/inventory_editor_components/inventory_form_builder.dart';

class ConsumableForm extends ConsumerStatefulWidget {
  final ConsumableItem? item;

  const ConsumableForm({super.key, this.item});

  @override
  ConsumerState<ConsumableForm> createState() => _ConsumableFormState();
}

class _ConsumableFormState extends ConsumerState<ConsumableForm> {
  final _formKey = GlobalKey<FormState>();

  final _generic = TextEditingController();
  final _brand = TextEditingController();
  final _desc = TextEditingController();
  final _size = TextEditingController();
  final _packSize = TextEditingController();
  final _unit = TextEditingController();
  final _package = TextEditingController();
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
      _desc,
      _size,
      _packSize,
      _unit,
      _package,
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
      fields: _buildFields(),
      onSubmit: _submit,
      buttonLabel: widget.item == null
          ? 'Save Consumable'
          : 'Update Consumable',
    );
  }

  List<Widget> _buildFields() => [
    buildRequiredField(_generic, 'Generic Name *'),
    buildField(_brand, 'Brand Name'),
    buildField(_desc, 'Description'),
    buildField(_size, 'Size'),
    buildField(_packSize, 'Pack Size'),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.consumable,
      preferenceField: ItemPreferenceField.unit,
      label: 'Unit',
      initialValue: _unit.text,
      onChanged: (val) => _unit.text = val,
    ),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.consumable,
      preferenceField: ItemPreferenceField.package,
      label: 'Package',
      initialValue: _package.text,
      onChanged: (val) => _package.text = val,
    ),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.consumable,
      preferenceField: ItemPreferenceField.group,
      label: 'Group *',
      initialValue: _group.text,
      onChanged: (val) => _group.text = val,
    ),
    const SizedBox(height: 16),
    buildField(_reorder, 'Reorder Level'),
    buildField(_proposed, 'Proposed Order'),
  ];

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isNew = widget.item == null;
    final id = isNew ? const Uuid().v4() : widget.item!.id;

    final formData = {
      'id': id,
      'itemType': ItemType.consumable.name, // ✅ Ensure type is always set
      'name': _generic.text.trim(),
      'brandName': _nullable(_brand),
      'description': _nullable(_desc),
      'size': _nullable(_size),
      'packSize': _nullable(_packSize),
      'unit': _nullable(_unit),
      'package': _nullable(_package),
      'group': _group.text.trim(),
      'reorderLevel': _intValue(_reorder),
      'proposedOrder': _intValue(_proposed),
    };

    final item = ConsumableItem.fromMap(id!, formData);
    final controller = ref.read(consumableControllerProvider);

    if (isNew) {
      await controller.create(item);
    } else {
      await controller.update(item);
    }

    if (context.mounted) Navigator.of(context).pop(); // ✅ Pop after success
  }

  void _populate(ConsumableItem item) {
    _generic.text = item.name;
    _brand.text = item.brandName ?? '';
    _desc.text = item.description ?? '';
    _size.text = item.size ?? '';
    _packSize.text = item.packSize ?? '';
    _unit.text = item.unit ?? '';
    _package.text = item.package ?? '';
    _group.text = item.group;
    _reorder.text = item.reorderLevel?.toString() ?? '';
    _proposed.text = item.proposedOrder?.toString() ?? '';
  }

  String? _nullable(TextEditingController c) {
    final val = c.text.trim();
    return val.isEmpty ? null : val;
  }

  int? _intValue(TextEditingController c) {
    final val = c.text.trim();
    final num = int.tryParse(val);
    return (num != null && num >= 0) ? num : null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/controllers/forms/equipment_controller.dart';
import 'package:afyakit/features/inventory/items/screens/inventory_editor_components/inventory_field_helpers.dart';
import 'package:afyakit/features/inventory/items/screens/inventory_editor_components/inventory_form_builder.dart';
import 'package:afyakit/features/inventory/preferences/widgets/item_preference_autocomplete_field.dart';
import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

class EquipmentForm extends ConsumerStatefulWidget {
  final EquipmentItem? item;

  const EquipmentForm({super.key, this.item});

  @override
  ConsumerState<EquipmentForm> createState() => _EquipmentFormState();
}

class _EquipmentFormState extends ConsumerState<EquipmentForm> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _group = TextEditingController();
  final _description = TextEditingController();
  final _model = TextEditingController();
  final _manufacturer = TextEditingController();
  final _serial = TextEditingController();
  final _package = TextEditingController();
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
      _name,
      _group,
      _description,
      _model,
      _manufacturer,
      _serial,
      _package,
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
      buttonLabel: widget.item == null ? 'Save Equipment' : 'Update Equipment',
    );
  }

  List<Widget> _buildFields() => [
    buildRequiredField(_name, 'Equipment Name *'),
    buildField(_description, 'Description'),
    buildField(_model, 'Model'),
    buildField(_manufacturer, 'Manufacturer'),
    buildField(_serial, 'Serial Number'),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.equipment,
      preferenceField: ItemPreferenceField.package,
      label: 'Package',
      initialValue: _package.text,
      onChanged: (val) => _package.text = val,
    ),
    const SizedBox(height: 16),
    ItemPreferenceAutocompleteField(
      itemType: ItemType.equipment,
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
      'itemType': ItemType.equipment.name, // ✅ Explicitly include item type
      'name': _name.text.trim(),
      'group': _group.text.trim(),
      'description': _nullable(_description),
      'model': _nullable(_model),
      'manufacturer': _nullable(_manufacturer),
      'serialNumber': _nullable(_serial),
      'package': _nullable(_package),
      'reorderLevel': _intValue(_reorder),
      'proposedOrder': _intValue(_proposed),
    };

    final item = EquipmentItem.fromMap(id!, data);
    final controller = ref.read(equipmentControllerProvider);

    if (isNew) {
      await controller.create(item);
    } else {
      await controller.update(item);
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _populate(EquipmentItem item) {
    _name.text = item.name;
    _group.text = item.group;
    _description.text = item.description ?? '';
    _model.text = item.model ?? '';
    _manufacturer.text = item.manufacturer ?? '';
    _serial.text = item.serialNumber ?? '';
    _package.text = item.package ?? '';
    _reorder.text = item.reorderLevel?.toString() ?? '';
    _proposed.text = item.proposedOrder?.toString() ?? '';
  }

  String? _nullable(TextEditingController c) {
    final val = c.text.trim();
    return val.isEmpty ? null : val;
  }

  int? _intValue(TextEditingController c) {
    final val = c.text.trim();
    final parsed = int.tryParse(val);
    return (parsed != null && parsed >= 0) ? parsed : null;
  }
}

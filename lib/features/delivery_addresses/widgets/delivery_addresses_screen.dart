// lib/features/delivery_addresses/widgets/delivery_addresses_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/delivery_addresses/controllers/delivery_address_controller.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/providers/delivery_address_providers.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_pin_picker_screen.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class DeliveryAddressesScreen extends ConsumerWidget {
  const DeliveryAddressesScreen({super.key, this.pickerMode = false});

  final bool pickerMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deliveryAddressStateProvider);
    final controller = ref.read(deliveryAddressControllerProvider.notifier);
    final launcher = ref.read(deliveryNavigationLauncherProvider);

    final title = pickerMode ? 'Select Delivery Address' : 'Delivery Addresses';

    return AppPage(
      title: title,
      showBack: true,
      maxWidth: AppLayout.memberPageMaxW,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Add address',
          onPressed: () => _showAddressSheet(context, existing: null),
          icon: const Icon(Icons.add),
        ),
      ],
      fab: FloatingActionButton(
        onPressed: () => _showAddressSheet(context, existing: null),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.hasActiveItems) {
            return _EmptyState(
              pickerMode: pickerMode,
              onAddPressed: () => _showAddressSheet(context, existing: null),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: state.activeItems.length,
            itemBuilder: (context, index) {
              final address = state.activeItems[index];

              return _AddressCard(
                address: address,
                pickerMode: pickerMode,
                onSelect: pickerMode
                    ? () => Navigator.of(context).pop<DeliveryAddress>(address)
                    : null,
                onEdit: () => _showAddressSheet(context, existing: address),
                onNavigate: address.pinLocation == null
                    ? null
                    : () async {
                        try {
                          await launcher.navigateTo(address);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                onSetDefault: () async {
                  await controller.setDefault(address.id);
                  if (context.mounted) {
                    final error = ref.read(deliveryAddressErrorProvider);
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Default address updated'),
                        ),
                      );
                    }
                  }
                },
                onArchive: () => _confirmArchive(
                  context,
                  onConfirm: () async {
                    await controller.archive(address.id);
                    if (context.mounted) {
                      final error = ref.read(deliveryAddressErrorProvider);
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address removed')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddressSheet(BuildContext context, {DeliveryAddress? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddressFormSheet(existing: existing),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove address?'),
        content: const Text(
          'This address will be archived and removed from your active list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
    }
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.pickerMode,
    required this.onEdit,
    required this.onNavigate,
    required this.onSetDefault,
    required this.onArchive,
    this.onSelect,
  });

  final DeliveryAddress address;
  final bool pickerMode;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onNavigate;
  final VoidCallback onSetDefault;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cardChild = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  address.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (address.isDefault) const Chip(label: Text('Default')),
              if (pickerMode) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(address.recipientDisplay),
          if (address.fullDisplay.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(address.fullDisplay),
          ],
          if (address.pinLocation != null) ...[
            const SizedBox(height: 6),
            Text(
              address.pinLocation!.placeName?.trim().isNotEmpty == true
                  ? 'Pin: ${address.pinLocation!.placeName}'
                  : 'Pin: '
                        '${address.pinLocation!.latitude.toStringAsFixed(6)}, '
                        '${address.pinLocation!.longitude.toStringAsFixed(6)}',
            ),
          ],
          if ((address.instructions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Instructions: ${address.instructions!.trim()}'),
          ],
          if (!pickerMode) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate'),
                ),
                TextButton(
                  onPressed: address.isDefault ? null : onSetDefault,
                  child: const Text('Set Default'),
                ),
                TextButton(onPressed: onArchive, child: const Text('Remove')),
              ],
            ),
          ],
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: pickerMode
          ? InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSelect,
              child: cardChild,
            )
          : cardChild,
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.existing});

  final DeliveryAddress? existing;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _recipientNameController;
  late final TextEditingController _recipientPhoneController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _areaController;
  late final TextEditingController _cityController;
  late final TextEditingController _countyController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _instructionsController;

  late bool _isDefault;
  DeliveryPinLocation? _pinLocation;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _labelController = TextEditingController(text: existing?.label ?? '');
    _recipientNameController = TextEditingController(
      text: existing?.recipientName ?? '',
    );
    _recipientPhoneController = TextEditingController(
      text: existing?.recipientPhone ?? '',
    );
    _line1Controller = TextEditingController(text: existing?.line1 ?? '');
    _line2Controller = TextEditingController(text: existing?.line2 ?? '');
    _areaController = TextEditingController(text: existing?.area ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _countyController = TextEditingController(text: existing?.county ?? '');
    _landmarkController = TextEditingController(text: existing?.landmark ?? '');
    _instructionsController = TextEditingController(
      text: existing?.instructions ?? '',
    );

    _isDefault = existing?.isDefault ?? false;
    _pinLocation = existing?.pinLocation;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(deliveryAddressBusyProvider);
    final controller = ref.read(deliveryAddressControllerProvider.notifier);
    final title = _isEdit ? 'Edit Address' : 'Add Address';

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.memberPageMaxW),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _labelController,
                      label: 'Label',
                      hint: 'Home, Office, Mum\'s place',
                      required: true,
                    ),
                    _field(
                      controller: _recipientNameController,
                      label: 'Recipient Name',
                      required: true,
                    ),
                    _field(
                      controller: _recipientPhoneController,
                      label: 'Recipient Phone',
                      keyboardType: TextInputType.phone,
                      required: true,
                    ),
                    _field(
                      controller: _line1Controller,
                      label: 'Address Line 1',
                      hint: 'Building, house, road, street',
                      required: true,
                    ),
                    _field(
                      controller: _line2Controller,
                      label: 'Address Line 2',
                      hint: 'Apartment, floor, unit',
                    ),
                    _field(
                      controller: _areaController,
                      label: 'Area / Estate',
                      required: true,
                    ),
                    _field(
                      controller: _cityController,
                      label: 'City / Town',
                      required: true,
                    ),
                    _field(controller: _countyController, label: 'County'),
                    _field(controller: _landmarkController, label: 'Landmark'),
                    _field(
                      controller: _instructionsController,
                      label: 'Delivery Instructions',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 4),
                    _PinTile(
                      pinLocation: _pinLocation,
                      busy: busy,
                      onPick: () => _pickPin(context),
                      onClear: _pinLocation == null
                          ? null
                          : () => setState(() => _pinLocation = null),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _isDefault = value),
                      title: const Text('Set as default'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : () => _submit(controller),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'Save Changes' : 'Save Address'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPin(BuildContext context) async {
    final picked = await Navigator.of(context).push<DeliveryPinLocation>(
      MaterialPageRoute(
        builder: (_) => DeliveryPinPickerScreen(initialPin: _pinLocation),
      ),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _pinLocation = picked;
    });
  }

  Future<void> _submit(DeliveryAddressController controller) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await controller.submitForm(
      existing: widget.existing,
      label: _labelController.text,
      recipientName: _recipientNameController.text,
      recipientPhone: _recipientPhoneController.text,
      line1: _line1Controller.text,
      line2: _line2Controller.text,
      area: _areaController.text,
      city: _cityController.text,
      county: _countyController.text,
      landmark: _landmarkController.text,
      instructions: _instructionsController.text,
      pinLocation: _pinLocation,
      isDefault: _isDefault,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Address updated' : 'Address saved')),
      );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _PinTile extends StatelessWidget {
  const _PinTile({
    required this.pinLocation,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final DeliveryPinLocation? pinLocation;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasPin = pinLocation != null;
    final subtitle = hasPin
        ? (pinLocation!.placeName?.trim().isNotEmpty == true
              ? '${pinLocation!.placeName}\n'
                    '${pinLocation!.latitude.toStringAsFixed(6)}, '
                    '${pinLocation!.longitude.toStringAsFixed(6)}'
              : '${pinLocation!.latitude.toStringAsFixed(6)}, '
                    '${pinLocation!.longitude.toStringAsFixed(6)}')
        : 'No pin selected';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('Pin location'),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (hasPin)
              TextButton(
                onPressed: busy ? null : onClear,
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: busy ? null : onPick,
              child: Text(hasPin ? 'Change' : 'Drop Pin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.pickerMode, required this.onAddPressed});

  final bool pickerMode;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pickerMode
                  ? 'No delivery addresses yet.\nAdd one to continue.'
                  : 'No delivery addresses yet.\nTap + to add one.',
              textAlign: TextAlign.center,
            ),
            if (pickerMode) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add),
                label: const Text('Add Address'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

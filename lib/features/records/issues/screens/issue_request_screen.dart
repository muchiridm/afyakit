import 'package:afyakit/features/records/issues/providers/grouped_cart_provider.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/features/records/issues/controllers/controllers/issue_form_controller.dart';
import 'package:afyakit/features/records/issues/controllers/controllers/multi_cart_controller.dart';
import 'package:afyakit/features/records/issues/controllers/states/issue_record_state.dart';
import 'package:afyakit/features/records/issues/controllers/states/multi_cart_state.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

class IssueRequestScreen extends ConsumerWidget {
  const IssueRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(issueFormControllerProvider);
    final formController = ref.read(issueFormControllerProvider.notifier);
    final cart = ref.watch(multiCartProvider);

    final stores = ref
        .watch(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(
          data: (d) => d.cast<InventoryLocation>(),
          orElse: () => <InventoryLocation>[],
        );

    final dispensaries = ref
        .watch(inventoryLocationProvider(InventoryLocationType.dispensary))
        .maybeWhen(
          data: (d) => d.cast<InventoryLocation>(),
          orElse: () => <InventoryLocation>[],
        );

    final destinations = formState.type == IssueType.dispense
        ? dispensaries
        : stores;

    return BaseScreen(
      scrollable: true,
      maxContentWidth: 700,
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: ScreenHeader('Issue Request'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildTypeSelector(formController, formState.type),
          const SizedBox(height: 16),
          _buildDatePicker(context, formController, formState.requestDate),
          const SizedBox(height: 16),
          if (formState.type != IssueType.dispose)
            _buildDestinationDropdown(
              destinations: destinations,
              selected: formState.toStore,
              onChanged: formController.setDestination,
            ),
          const SizedBox(height: 20),
          _buildMultiCartSummary(ref, stores),
          const SizedBox(height: 24),
          _buildSubmitButton(context, formController, formState, cart),
          const SizedBox(height: 20),
          _buildNoteInput(formController),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(
    IssueFormController controller,
    IssueType selected,
  ) {
    return Wrap(
      spacing: 8,
      children: IssueType.values.map((type) {
        return ChoiceChip(
          label: Text(_labelForType(type)),
          selected: selected == type,
          onSelected: (_) => controller.setType(type),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    IssueFormController controller,
    DateTime selected,
  ) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Request Date',
        border: OutlineInputBorder(),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selected,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) controller.setRequestDate(picked);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd/MM/yyyy').format(selected)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationDropdown({
    required List<InventoryLocation> destinations,
    required String? selected,
    required void Function(String?) onChanged,
  }) {
    if (destinations.isEmpty) {
      return const Text('No locations available');
    }

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'To Destination',
        border: OutlineInputBorder(),
      ),
      items: destinations.map((loc) {
        return DropdownMenuItem<String>(value: loc.id, child: Text(loc.name));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNoteInput(IssueFormController controller) {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        border: OutlineInputBorder(),
      ),
      minLines: 2,
      maxLines: 3,
      onChanged: controller.setNote,
    );
  }

  Widget _buildMultiCartSummary(WidgetRef ref, List<InventoryLocation> stores) {
    final displayGroups = ref.watch(groupedCartProvider);

    if (displayGroups.isEmpty) {
      return const Text('No items selected.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayGroups.entries.map((entry) {
        final storeId = entry.key;
        final items = entry.value;

        final totalQty = items
            .map(
              (e) => e.batches.map((b) => b.quantity).fold(0, (a, b) => a + b),
            )
            .fold(0, (a, b) => a + b);

        final totalBatches = items.fold(
          0,
          (sum, item) => sum + item.batches.length,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🛒 Store: ${resolveLocationName(storeId, stores, [])}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              Text('• Items: ${items.length}'),
              Text('• Batches: $totalBatches'),
              Text('• Quantity: $totalQty'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    IssueFormController controller,
    IssueRecordState state,
    MultiCartState cart,
  ) {
    final hasItems = cart.cartsByStore.values.any((c) => c.isNotEmpty);
    final needsDestination =
        state.type != IssueType.dispose &&
        (state.toStore?.trim().isEmpty ?? true);

    final isDisabled = state.isSubmitting || !hasItems || needsDestination;

    return ElevatedButton.icon(
      icon: const Icon(Icons.check),
      label: const Text(
        'Submit Request',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: isDisabled ? null : () => controller.submit(context),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade400,
      ),
    );
  }

  String _labelForType(IssueType type) {
    return switch (type) {
      IssueType.dispense => 'Dispense',
      IssueType.transfer => 'Transfer',
      IssueType.dispose => 'Dispose',
    };
  }
}

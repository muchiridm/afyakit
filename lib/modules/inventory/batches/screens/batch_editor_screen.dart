// lib/features/batches/screens/batch_editor_screen.dart
import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/modules/inventory/batches/controllers/batch_args.dart';
import 'package:afyakit/modules/inventory/batches/controllers/batch_controller.dart';
import 'package:afyakit/modules/inventory/batches/controllers/batch_state.dart';
import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/modules/inventory/batches/models/dropdown_option.dart';
import 'package:afyakit/modules/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BatchEditorScreen extends ConsumerWidget {
  final String tenantId;
  final BaseInventoryItem item;
  final BatchEditorMode mode;
  final BatchRecord? batch;

  const BatchEditorScreen({
    super.key,
    required this.tenantId,
    required this.item,
    required this.mode,
    this.batch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = BatchArgs(
      tenantId: tenantId,
      item: item,
      batch: batch,
      mode: mode,
    );

    final provider = batchEditorProvider(args);
    final controller = ref.watch(provider.notifier);
    final state = ref.watch(provider);
    final isEditing = mode == BatchEditorMode.edit;

    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );
    final sourcesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.source),
    );
    final sessionAsync = ref.watch(currentUserProvider);

    return sessionAsync.when(
      loading: _loader,
      error: _error,
      data: (user) {
        if (user == null) {
          return const Center(child: Text('❌ No user session found'));
        }

        return BaseScreen(
          scrollable: false,
          maxContentWidth: 800,
          header: ScreenHeader(
            isEditing ? 'Edit Batch' : 'Add Batch',
            trailing: isEditing
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Delete Batch',
                    onPressed: () async {
                      final ok = await controller.delete();
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
                  )
                : null,
          ),
          body: storesAsync.when(
            loading: _loader,
            error: _error,
            data: (stores) {
              final storeOptions = _toStoreOptions(
                stores: stores,
                currentStoreId: state.storeId,
              );

              return sourcesAsync.when(
                loading: _loader,
                error: _error,
                data: (sources) {
                  final sourceOptions = _toSourceOptions(
                    sources: sources,
                    currentSource: state.source,
                  );

                  return _buildForm(
                    context,
                    controller,
                    state,
                    isEditing,
                    storeOptions,
                    sourceOptions,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── UI builders ───────────────────────────────────────────────

  Widget _buildForm(
    BuildContext context,
    BatchEditorController controller,
    BatchState state,
    bool isEditing,
    List<DropdownOption<String>> storeOptions,
    List<DropdownOption<String>> sourceOptions,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkuSummary(item),
                _buildDatePicker(
                  context,
                  label: 'Received Date *',
                  date: state.receivedDate,
                  onPicked: controller.updateReceivedDate,
                ),
                const SizedBox(height: 12),
                _buildDatePicker(
                  context,
                  label: 'Expiry Date (optional)',
                  date: state.expiryDate,
                  onPicked: controller.updateExpiryDate,
                  isRequired: false,
                ),
                const SizedBox(height: 12),
                _buildQuantityField(state.quantity, controller.updateQuantity),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Receiving Store *',
                  value: state.storeId,
                  options: storeOptions,
                  onChanged: isEditing ? null : controller.updateStore,
                  readOnly: isEditing,
                ),
                if (isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '🔒 Store cannot be changed after batch creation.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                if (sourceOptions.isEmpty)
                  const Text(
                    '⚠️ No source locations available. Please add some in Locations.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  _buildDropdown(
                    label: 'Source *',
                    value: state.source,
                    options: sourceOptions,
                    onChanged: controller.updateSource,
                  ),
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  _buildEditReasonField(
                    state.editReason,
                    controller.updateEditReason,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await controller.save();
                if (ok && context.mounted) Navigator.of(context).pop();
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Batch'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkuSummary(BaseInventoryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Item',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Text(
            // Keep the screen dumb: show only name + type
            '${item.name} • ${item.type.name.toUpperCase()}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required void Function(DateTime?) onPicked,
    bool isRequired = true,
  }) {
    final formatted = date != null
        ? DateFormat('yyyy-MM-dd').format(date)
        : '—';
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isRequired && date != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear date',
                  onPressed: () => onPicked(null),
                ),
              const Icon(Icons.calendar_today),
            ],
          ),
        ),
        child: Text(formatted, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildQuantityField(
    String? quantity,
    void Function(String) onChanged,
  ) {
    return TextFormField(
      initialValue: quantity,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Quantity *',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildEditReasonField(
    String? reason,
    void Function(String) onChanged,
  ) {
    return TextFormField(
      initialValue: reason,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Reason for Edit *',
        hintText: 'E.g. Corrected quantity or date',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownOption<T>> options,
    required void Function(T?)? onChanged,
    bool readOnly = false,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: readOnly ? const Icon(Icons.lock_outline, size: 20) : null,
      ),
      isExpanded: true,
      initialValue: options.any((o) => o.value == value) ? value : null,
      onChanged: readOnly ? null : onChanged,
      items: options
          .map(
            (opt) =>
                DropdownMenuItem<T>(value: opt.value, child: Text(opt.label)),
          )
          .toList(),
    );
  }

  Widget _loader() => const Center(child: CircularProgressIndicator());
  Widget _error(Object e, StackTrace _) =>
      Center(child: Text('Error loading data: $e'));

  // ── helpers to keep UI dumb but resilient ─────────────────────

  List<DropdownOption<String>> _toStoreOptions({
    required List<InventoryLocation> stores,
    required String? currentStoreId,
  }) {
    final opts = [
      for (final s in stores)
        DropdownOption<String>(value: s.id, label: s.name),
    ];

    // If editing and the current store isn’t in the loaded list, include it so the UI displays correctly.
    if (currentStoreId != null &&
        currentStoreId.isNotEmpty &&
        !opts.any((o) => o.value == currentStoreId)) {
      opts.add(
        DropdownOption<String>(value: currentStoreId, label: 'Unknown Store'),
      );
    }
    return opts;
  }

  List<DropdownOption<String>> _toSourceOptions({
    required List<InventoryLocation> sources,
    required String? currentSource,
  }) {
    final names = {...sources.map((s) => s.name)};
    if (currentSource != null && currentSource.isNotEmpty) {
      names.add(currentSource);
    }
    final sortedNames = names.toList()..sort();
    return sortedNames
        .map((n) => DropdownOption<String>(value: n, label: n))
        .toList();
  }
}

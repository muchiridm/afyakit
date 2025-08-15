import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/shared/screens/detail_record_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:afyakit/shared/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/records/delivery_sessions/models/delivery_record.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';

import 'package:afyakit/features/inventory/providers/item_streams/consumable_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/equipment_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/medication_items_stream_provider.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/services/sku_batch_matcher.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

class DeliveryDetailScreen extends ConsumerWidget {
  final DeliveryRecord summary;
  final List<InventoryLocation> stores;

  const DeliveryDetailScreen({
    super.key,
    required this.summary,
    required this.stores,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final medsAsync = ref.watch(medicationItemsStreamProvider(tenantId));
    final consAsync = ref.watch(consumableItemsStreamProvider(tenantId));
    final equipAsync = ref.watch(equipmentItemsStreamProvider(tenantId));

    return medsAsync.when(
      loading: _loading,
      error: _error,
      data: (meds) => consAsync.when(
        loading: _loading,
        error: _error,
        data: (cons) => equipAsync.when(
          loading: _loading,
          error: _error,
          data: (equip) => _buildBody(context, [...meds, ...cons, ...equip]),
        ),
      ),
    );
  }

  Widget _loading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _error(Object error, StackTrace _) =>
      Scaffold(body: Center(child: Text('Error loading data: $error')));

  Widget _buildBody(BuildContext context, List<BaseInventoryItem> allItems) {
    final batches = summary.batchSnapshots.map(BatchRecord.fromMap).toList();
    final matcher = SkuBatchMatcher.from(items: allItems, batches: batches);

    final sorted = [...batches]
      ..sort((a, b) => _sortKey(a, matcher).compareTo(_sortKey(b, matcher)));

    return DetailRecordScreen(
      maxContentWidth: 900,
      header: ScreenHeader(
        'Delivery: ${summary.deliveryId}',
        trailing: Text(
          'Total Qty: ${summary.totalQuantity}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      contentSections: [
        _buildMetaCard(summary),
        ...sorted.map((b) => _buildBatchCard(b, matcher)),
      ],
    );
  }

  Widget _buildMetaCard(DeliveryRecord summary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metaRow('Date', formatDate(summary.date)),
            const SizedBox(height: 8),
            _metaRow(
              'Entered By',
              '${summary.enteredByName} (${summary.enteredByEmail})',
            ),
            const SizedBox(height: 8),
            _metaRow('Sources', summary.sources.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) => RichText(
    text: TextSpan(
      style: const TextStyle(color: Colors.black87),
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: value),
      ],
    ),
  );

  Widget _buildBatchCard(BatchRecord batch, SkuBatchMatcher matcher) {
    final label = _buildItemLabel(batch, matcher);
    final expiry = batch.expiryDate != null
        ? ' • Exp: ${formatDate(batch.expiryDate!)}'
        : '';
    final statusText = batch.isEdited ? 'Edited' : 'New';
    final statusIcon = batch.isEdited ? Icons.edit : Icons.fiber_new;
    final statusColor = batch.isEdited ? Colors.orange : Colors.teal;
    final isSoonExpiring =
        batch.expiryDate != null &&
        batch.expiryDate!.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        );
    final storeName = resolveLocationName(batch.storeId, stores, []);

    final detailLine =
        'Qty: ${batch.quantity} • Store: $storeName • ${_formatEnum(batch.itemType.name)}$expiry';
    final editLine = batch.isEdited && (batch.editReason?.isNotEmpty ?? false)
        ? 'Reason: ${batch.editReason}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detailLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSoonExpiring ? Colors.redAccent : null,
                    ),
                  ),
                  if (editLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        editLine,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              label: Text(statusText, style: const TextStyle(fontSize: 11)),
              avatar: Icon(statusIcon, size: 14, color: statusColor),
              backgroundColor: statusColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildItemLabel(BatchRecord batch, SkuBatchMatcher matcher) {
    final item = matcher.getItem(batch.itemId);
    if (item == null) return 'Unknown Item';

    return switch (item) {
      MedicationItem m => joinNonEmpty([
        m.group,
        m.name,
        m.brandName,
        m.strength,
        m.route?.join(', '),
        m.formulation,
        if (m.packSize != null) 'Pack: ${m.packSize}',
      ]),
      ConsumableItem c => joinNonEmpty([
        c.group,
        c.name,
        c.brandName,
        c.description,
        if (c.size != null) 'Size: ${c.size}',
        if (c.unit != null) 'Unit: ${c.unit}',
        if (c.packSize != null) 'Pack: ${c.packSize}',
        c.package,
      ]),
      EquipmentItem e => joinNonEmpty([
        e.group,
        e.name,
        e.description,
        e.model,
        e.manufacturer,
        if (e.serialNumber?.isNotEmpty ?? false) 'Serial: ${e.serialNumber}',
        e.package,
      ]),
      _ => 'Unknown Item',
    };
  }

  String _sortKey(BatchRecord batch, SkuBatchMatcher matcher) {
    final item = matcher.getItem(batch.itemId);
    return item?.name.trim().toLowerCase() ?? 'unknown';
  }

  String _formatEnum(String value) => value.isEmpty
      ? ''
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

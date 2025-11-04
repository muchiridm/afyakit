import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/providers/item_stream_providers.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/widgets/records/detail_record_screen.dart';
import 'package:afyakit/shared/widgets/screen_header/screen_header.dart';
import 'package:afyakit/shared/services/sku_batch_matcher.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:afyakit/shared/utils/string_utils.dart';

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

    Widget loading() =>
        const Scaffold(body: Center(child: CircularProgressIndicator()));
    Widget error(Object e, StackTrace _) =>
        Scaffold(body: Center(child: Text('Error loading data: $e')));

    return medsAsync.when(
      loading: loading,
      error: error,
      data: (meds) => consAsync.when(
        loading: loading,
        error: error,
        data: (cons) => equipAsync.when(
          loading: loading,
          error: error,
          data: (equip) => _buildBody(context, [...meds, ...cons, ...equip]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────

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
        _metaCard(summary),
        ...sorted.map((b) => _batchCard(b, matcher)),
      ],
    );
  }

  // ───────────────────────── meta ─────────────────────────

  Widget _metaCard(DeliveryRecord s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _metaList([
          ('Date', formatDate(s.date)),
          ('Entered By', _enteredByLine(s)),
          ('Sources', s.sources.join(', ')),
        ]),
      ),
    );
  }

  /// Always prefer "Name (email)" when both exist and differ.
  /// Fallbacks:
  /// - name only if email missing
  /// - email only if name missing or equals email (avoid "email (email)")
  /// - "-" if both blank
  String _enteredByLine(DeliveryRecord s) {
    final name = s.enteredByName.trim();
    final email = s.enteredByEmail.trim();

    if (name.isEmpty && email.isEmpty) return '-';
    if (name.isEmpty) return email;
    if (email.isEmpty) return name;
    if (name.toLowerCase() == email.toLowerCase()) return email;
    return '$name ($email)';
  }

  Widget _metaList(List<(String, String)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children:
        rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _metaRow(r.$1, r.$2),
              ),
            )
            .toList()
          ..removeLast(), // trim last gap
  );

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

  // ──────────────────────── batch cards ────────────────────────

  Widget _batchCard(BatchRecord batch, SkuBatchMatcher matcher) {
    final label = _itemLabel(batch, matcher);

    final expiryText = batch.expiryDate != null
        ? ' • Exp: ${formatDate(batch.expiryDate!)}'
        : '';
    final soonExpiring =
        batch.expiryDate != null &&
        batch.expiryDate!.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        );

    final storeName = resolveLocationName(batch.storeId, stores, []);
    final detailLine =
        'Qty: ${batch.quantity} • Store: $storeName • ${_formatEnum(batch.itemType.name)}$expiryText';

    final isEdited = batch.isEdited;
    final statusText = isEdited ? 'Edited' : 'New';
    final statusIcon = isEdited ? Icons.edit : Icons.fiber_new;
    final statusColor = isEdited ? Colors.orange : Colors.teal;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _column([
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  detailLine,
                  style: TextStyle(
                    fontSize: 13,
                    color: soonExpiring ? Colors.redAccent : null,
                  ),
                ),
                if (isEdited && (batch.editReason?.isNotEmpty ?? false))
                  Text(
                    'Reason: ${batch.editReason}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
              ], gap: 6),
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

  // ───────────────────────── helpers ─────────────────────────

  Widget _column(List<Widget> children, {double gap = 8}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );

  String _itemLabel(BatchRecord batch, SkuBatchMatcher matcher) {
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

  String _sortKey(BatchRecord batch, SkuBatchMatcher matcher) =>
      matcher.getItem(batch.itemId)?.name.trim().toLowerCase() ?? 'unknown';

  String _formatEnum(String value) => value.isEmpty
      ? ''
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

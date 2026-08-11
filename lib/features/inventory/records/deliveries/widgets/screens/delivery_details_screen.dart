// lib/features/inventory/records/deliveries/widgets/screens/delivery_details_screen.dart

import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_record_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/batches/models/batch_record.dart';

import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/items/providers/item_stream_providers.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';

import 'package:afyakit/features/inventory/records/deliveries/models/delivery_record.dart';

import 'package:afyakit/features/inventory/records/shared/detail_record_screen.dart';
import 'package:afyakit/features/inventory/shared/sku_batch_matcher.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:afyakit/shared/utils/string_utils.dart';

class DeliveryDetailScreen extends ConsumerWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(deliveryRecordProvider(deliveryId));

    return recordAsync.when(
      loading: () => const AppPage(
        scrollable: false,
        header: AppHeader(title: 'Delivery'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AppPage(
        scrollable: false,
        header: const AppHeader(title: 'Delivery'),
        body: Center(child: Text('Error loading delivery: $error')),
      ),
      data: (summary) => _DeliveryDetailBody(summary: summary),
    );
  }
}

class _DeliveryDetailBody extends ConsumerWidget {
  const _DeliveryDetailBody({required this.summary});

  final DeliveryRecord summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    final stores = ref.watch(allStoresProvider);

    final dispensaries = ref.watch(allDispensariesProvider);

    final medsAsync = ref.watch(medicationItemsStreamProvider(tenantId));

    final consAsync = ref.watch(consumableItemsStreamProvider(tenantId));

    final equipAsync = ref.watch(equipmentItemsStreamProvider(tenantId));

    Widget loading() => const AppPage(
      scrollable: false,
      header: AppHeader(title: 'Delivery'),
      body: Center(child: CircularProgressIndicator()),
    );

    Widget error(Object error, StackTrace _) => AppPage(
      scrollable: false,
      header: const AppHeader(title: 'Delivery'),
      body: Center(child: Text('Error loading inventory data: $error')),
    );

    return medsAsync.when(
      loading: loading,
      error: error,
      data: (meds) => consAsync.when(
        loading: loading,
        error: error,
        data: (cons) => equipAsync.when(
          loading: loading,
          error: error,
          data: (equip) => _buildBody(
            context,
            items: [...meds, ...cons, ...equip],
            stores: stores,
            dispensaries: dispensaries,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<BaseInventoryItem> items,
    required List<InventoryLocation> stores,
    required List<InventoryLocation> dispensaries,
  }) {
    final batches = summary.batchSnapshots.map(BatchRecord.fromMap).toList();

    final matcher = SkuBatchMatcher.from(items: items, batches: batches);

    final sorted = [...batches]
      ..sort((a, b) => _sortKey(a, matcher).compareTo(_sortKey(b, matcher)));

    return DetailRecordScreen(
      maxContentWidth: 900,
      header: AppHeader(
        title: 'Delivery: ${summary.deliveryId}',
        trailing: Text(
          'Total Qty: ${summary.totalQuantity}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      contentSections: [
        _metaCard(summary),
        ...sorted.map(
          (batch) => _batchCard(batch, matcher, stores, dispensaries),
        ),
      ],
    );
  }

  // ───────────────────────── meta ─────────────────────────

  Widget _metaCard(DeliveryRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _metaList([
          ('Date', formatDate(record.date)),
          ('Entered By', _enteredByLine(record)),
          ('Sources', record.sources.isEmpty ? '-' : record.sources.join(', ')),
        ]),
      ),
    );
  }

  String _enteredByLine(DeliveryRecord record) {
    final name = record.enteredByName.trim();

    final email = record.enteredByEmail.trim();

    if (name.isEmpty && email.isEmpty) {
      return '-';
    }

    if (name.isEmpty) {
      return email;
    }

    if (email.isEmpty) {
      return name;
    }

    if (name.toLowerCase() == email.toLowerCase()) {
      return email;
    }

    return '$name ($email)';
  }

  Widget _metaList(List<(String, String)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _metaRow(rows[i].$1, rows[i].$2),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return RichText(
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
  }

  // ───────────────────── batch cards ──────────────────────

  Widget _batchCard(
    BatchRecord batch,
    SkuBatchMatcher matcher,
    List<InventoryLocation> stores,
    List<InventoryLocation> dispensaries,
  ) {
    final label = _itemLabel(batch, matcher);

    final expiryText = batch.expiryDate != null
        ? ' • Exp: ${formatDate(batch.expiryDate!)}'
        : '';

    final soonExpiring =
        batch.expiryDate != null &&
        batch.expiryDate!.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        );

    final storeName = resolveLocationName(batch.storeId, stores, dispensaries);

    final detailLine =
        'Qty: ${batch.quantity} • '
        'Store: $storeName • '
        '${_formatEnum(batch.itemType.name)}'
        '$expiryText';

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
              backgroundColor: statusColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── helpers ────────────────────────

  Widget _column(List<Widget> children, {double gap = 8}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }

  String _itemLabel(BatchRecord batch, SkuBatchMatcher matcher) {
    final item = matcher.getItem(batch.itemId);

    if (item == null) {
      // The backend review/finalized snapshot now carries
      // itemName, but BatchRecord does not expose it yet.
      return batch.itemId;
    }

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
      _ => batch.itemId,
    };
  }

  String _sortKey(BatchRecord batch, SkuBatchMatcher matcher) {
    return matcher.getItem(batch.itemId)?.name.trim().toLowerCase() ??
        batch.itemId.toLowerCase();
  }

  String _formatEnum(String value) {
    if (value.isEmpty) {
      return '';
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

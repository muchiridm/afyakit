import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssueSummaryPreview extends ConsumerWidget {
  final List<IssueEntry> entries;
  final List<BatchRecord> batches;

  const IssueSummaryPreview({
    super.key,
    required this.entries,
    required this.batches,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);

    return Column(
      children: entries.map((entry) {
        final batch = batches.firstWhere(
          (b) => b.id == entry.batchId,
          orElse: () => BatchRecord.blank(
            itemId: entry.itemId,
            itemType: entry.itemType,
            tenantId: tenantId,
            // If IssueEntry has a storeId field, use it here instead:
            storeId: '(unknown)',
          ),
        );

        final storeLabel =
            (batch.storeId.isEmpty || batch.storeId == '(unknown)')
            ? 'Unknown Store'
            : batch.storeId;

        final expiry = batch.expiryDate != null
            ? formatDate(batch.expiryDate!)
            : 'No Expiry';

        final subtitle = [
          'Group: ${entry.itemGroup}',
          if (entry.strength != null) 'Strength: ${entry.strength}',
          if (entry.size != null) 'Size: ${entry.size}',
          if (entry.formulation != null) 'Form: ${entry.formulation}',
          if (entry.packSize != null) 'Pack: ${entry.packSize}',
        ].where((s) => s.isNotEmpty).join(' • ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.itemName} (${entry.itemTypeLabel})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (subtitle.isNotEmpty) const SizedBox(height: 4),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13.5, color: Colors.grey),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  '- $storeLabel • $expiry • Qty: ${entry.quantity}',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

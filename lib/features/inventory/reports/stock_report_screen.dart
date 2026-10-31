import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'stock_report.dart';
import 'stock_report_providers.dart';

class StockReportScreen extends ConsumerStatefulWidget {
  const StockReportScreen({super.key, this.showToggleViewButton = false});
  final bool showToggleViewButton;
  @override
  ConsumerState<StockReportScreen> createState() => _StockReportScreenState();
}
class _StockReportScreenState extends ConsumerState<StockReportScreen> {
  String query = '';
  String? storeId;
  bool onlyLow = false;
  @override
  Widget build(BuildContext context) {
    final report = ref.watch(stockReportProvider);
    return AppPage(
      scrollable: true,
      maxWidth: 1300,
      header: const AppHeader(title: 'Stock Report'),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Could not load stock report: $error'),
          TextButton(onPressed: () => ref.invalidate(stockReportProvider), child: const Text('Retry')),
        ])),
        data: (data) => _reportBody(data),
      ),
    );
  }
  Widget _reportBody(StockReport report) {
    final stores = [...report.locations.where((l) => l.isStore && !l.isArchived)]
      ..sort((a,b) => a.name.compareTo(b.name));
    final rows = report.rows.where((row) {
      if (storeId != null && row.storeId != storeId) return false;
      if (onlyLow && !row.belowReorderLevel) return false;
      final q = query.trim().toLowerCase();
      return q.isEmpty || '${row.itemName} ${row.itemId} ${row.itemType} ${row.storeName}'.toLowerCase().contains(q);
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        const Text('Recorded batch quantities. These are not verified available-to-issue balances; unfinished delivery batches may be included.',
          style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Wrap(spacing: 12,runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 260,child: TextField(decoration: const InputDecoration(labelText: 'Search items or stores',prefixIcon: Icon(Icons.search)),onChanged: (v) => setState(() => query = v))),
          DropdownButton<String?>(value: storeId, hint: const Text('All stores'), items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All stores')),
            for (final s in stores) DropdownMenuItem<String?>(value: s.id,child: Text(s.name)),
          ], onChanged: (v) => setState(() => storeId = v)),
          FilterChip(label: const Text('Below reorder level'), selected: onlyLow, onSelected: (v) => setState(() => onlyLow = v)),
          IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(stockReportProvider),icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 12),
        Text('${rows.length} item/store rows', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal,child: DataTable(columns: const [
          DataColumn(label: Text('Store')),DataColumn(label: Text('Item')),DataColumn(label: Text('Type')),
          DataColumn(label: Text('Batches'),numeric: true), DataColumn(label: Text('Recorded qty'),numeric: true),
          DataColumn(label: Text('Reorder level'),numeric: true),
        ],rows: [for (final r in rows) DataRow(cells: [
          DataCell(Text(r.storeName)),DataCell(Text(r.itemName)),DataCell(Text(r.itemType)),
          DataCell(Text('${r.batchCount}')),DataCell(Text('${r.recordedQuantity}')),
          DataCell(Text(r.reorderLevel?.toString() ?? '—')),
        ])])),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_providers.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'inventory_issue.dart';
import 'inventory_issues_providers.dart';

class InventoryIssuesScreen extends ConsumerWidget {
  const InventoryIssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(inventoryIssuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock issues'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inventoryIssuesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New issue'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _NewIssueScreen()),
        ),
      ),
      body: issues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load issues: $error')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No stock issues yet'))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final issue = rows[index];
                  return ListTile(
                    title: Text(
                      '${issue.type.name.toUpperCase()} • ${issue.id}',
                    ),
                    subtitle: Text(
                      '${issue.status.name} • ${issue.entries.length} batches • ${issue.totalQuantity} units',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _IssueDetailsScreen(id: issue.id),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _IssueDetailsScreen extends ConsumerStatefulWidget {
  const _IssueDetailsScreen({required this.id});
  final String id;
  @override
  ConsumerState<_IssueDetailsScreen> createState() =>
      _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends ConsumerState<_IssueDetailsScreen> {
  bool busy = false;
  Future<void> _act(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final service = await ref.read(inventoryIssuesServiceProvider.future);
      await service.action(widget.id, action);
      ref.invalidate(inventoryIssueProvider(widget.id));
      ref.invalidate(inventoryIssuesProvider);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = ref.watch(inventoryIssueProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Issue details')),
      body: issue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load issue: $error')),
        data: (record) {
          final actions = switch (record.status) {
            InventoryIssueStatus.pending => const [
              'approve',
              'reject',
              'cancel',
            ],
            InventoryIssueStatus.approved => const ['issue', 'cancel'],
            InventoryIssueStatus.issued
                when record.type == InventoryIssueType.transfer =>
              const ['receive'],
            _ => const <String>[],
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                record.type.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Status: ${record.status.name}'),
              Text('From: ${record.fromLocationId}'),
              if (record.toLocationId != null)
                Text('To: ${record.toLocationId}'),
              if (record.note?.isNotEmpty == true) Text('Note: ${record.note}'),
              const SizedBox(height: 16),
              Text('Batches', style: Theme.of(context).textTheme.titleMedium),
              for (final entry in record.entries)
                ListTile(
                  title: Text(entry.batchId),
                  subtitle: Text('Item: ${entry.itemId}'),
                  trailing: Text('${entry.quantity}'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in actions)
                    OutlinedButton(
                      onPressed: busy ? null : () => _act(action),
                      child: Text(action.toUpperCase()),
                    ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}

class _NewIssueScreen extends ConsumerStatefulWidget {
  const _NewIssueScreen();
  @override
  ConsumerState<_NewIssueScreen> createState() => _NewIssueScreenState();
}

class _NewIssueScreenState extends ConsumerState<_NewIssueScreen> {
  final requestKey = 'issue_${DateTime.now().microsecondsSinceEpoch}';
  final note = TextEditingController();
  InventoryIssueType type = InventoryIssueType.transfer;
  String? fromId, toId;
  final quantities = <String, int>{};
  bool busy = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _submit(List<InventoryBatch> batches) async {
    if (busy || fromId == null) return;
    final rows = batches
        .where((b) => b.storeId == fromId && (quantities[b.id] ?? 0) > 0)
        .toList();
    final draft = InventoryIssueDraft(
      requestKey: requestKey,
      type: type,
      fromLocationId: fromId!,
      toLocationId: type == InventoryIssueType.transfer ? toId : null,
      note: note.text,
      entries: [
        for (final batch in rows)
          InventoryIssueEntry(
            batchId: batch.id,
            itemId: batch.itemId,
            quantity: quantities[batch.id]!,
          ),
      ],
    );
    try {
      draft.validate();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      return;
    }
    setState(() => busy = true);
    try {
      final service = await ref.read(inventoryIssuesServiceProvider.future);
      await service.create(draft);
      ref.invalidate(inventoryIssuesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(inventoryLocationsProvider(null));
    final batchState = ref.watch(inventoryBatchesProvider(fromId));
    return Scaffold(
      appBar: AppBar(title: const Text('Create stock issue')),
      body: locationState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load stores: $error')),
        data: (locations) {
          final stores = locations.where((s) => !s.isArchived).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<InventoryIssueType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Operation'),
                items: [
                  for (final t in InventoryIssueType.values)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        if (value != null) {
                          type = value;
                          toId = null;
                        }
                      }),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('source'),
                initialValue: fromId,
                decoration: const InputDecoration(labelText: 'Source store'),
                items: [
                  for (final store in stores)
                    DropdownMenuItem(value: store.id, child: Text(store.name)),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        fromId = value;
                        toId = null;
                        quantities.clear();
                      }),
              ),
              if (type == InventoryIssueType.transfer)
                DropdownButtonFormField<String>(
                  key: ValueKey('destination-$fromId'),
                  initialValue: toId,
                  decoration: const InputDecoration(
                    labelText: 'Destination store',
                  ),
                  items: [
                    for (final store in stores.where((s) => s.id != fromId))
                      DropdownMenuItem(
                        value: store.id,
                        child: Text(store.name),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => toId = value),
                ),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              Text(
                'Select quantities by batch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (fromId == null)
                const ListTile(title: Text('Select a source store first')),
              if (fromId != null)
                batchState.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      ListTile(title: Text('Unable to load batches: $error')),
                  data: (batches) => Column(
                    children: [
                      for (final batch in batches.where(
                        (b) =>
                            !b.isArchived &&
                            b.storeId == fromId &&
                            b.quantity > 0,
                      ))
                        ListTile(
                          title: Text(batch.batchNumber ?? batch.id),
                          subtitle: Text(
                            'Item: ${batch.itemId} • Available: ${batch.quantity}',
                          ),
                          trailing: SizedBox(
                            width: 90,
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: quantities[batch.id] ?? 0,
                              items: [
                                for (
                                  var i = 0;
                                  i <= batch.quantity && i <= 1000;
                                  i++
                                )
                                  DropdownMenuItem(value: i, child: Text('$i')),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() {
                                      if (v == null || v == 0) {
                                        quantities.remove(batch.id);
                                      } else {
                                        quantities[batch.id] = v;
                                      }
                                    }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy || fromId == null || !batchState.hasValue
                    ? null
                    : () => _submit(batchState.value!),
                child: const Text('Submit request'),
              ),
              if (busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}

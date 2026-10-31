import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'inventory_import.dart';
import 'inventory_import_providers.dart';

class InventoryImportScreen extends ConsumerStatefulWidget {
  const InventoryImportScreen({super.key});

  @override
  ConsumerState<InventoryImportScreen> createState() =>
      _InventoryImportScreenState();
}

class _InventoryImportScreenState extends ConsumerState<InventoryImportScreen> {
  String? _typeId;
  String? _filename;
  Uint8List? _bytes;
  InventoryImportResult? _validation;
  InventoryImportResult? _imported;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        setState(() => _error = 'Could not read the selected file.');
        return;
      }
      setState(() {
        _filename = file.name;
        _bytes = file.bytes;
        _validation = null;
        _imported = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _run({required bool persist}) async {
    final typeId = _typeId;
    final bytes = _bytes;
    final filename = _filename;
    if (typeId == null || filename == null || bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(inventoryImportServiceProvider.future);
      final result = persist
          ? await service.persist(
              typeId: typeId,
              filename: filename,
              bytes: bytes,
            )
          : await service.validate(
              typeId: typeId,
              filename: filename,
              bytes: bytes,
            );
      if (!mounted) return;
      setState(() {
        if (persist) {
          _imported = result;
        } else {
          _validation = result;
          _imported = null;
        }
      });
      if (persist && result.ok) {
        ref.invalidate(itemsProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _template() async {
    final typeId = _typeId;
    if (typeId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(inventoryImportServiceProvider.future);
      final bytes = await service.template(typeId);
      await FileSaver.instance.saveFile(
        name: '${typeId}_template',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.other,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(itemTypesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import Inventory Items')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose a configured item type, download its template, then validate your file before importing.',
          ),
          const SizedBox(height: 16),
          types.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load item types: $error'),
            data: (items) {
              final available = items.where((t) => t.isActive).toList();
              final selected = available.any((t) => t.typeId == _typeId)
                  ? _typeId
                  : null;
              return DropdownButtonFormField<String>(
                key: ValueKey(selected),
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Item type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final InventoryItemType type in available)
                    DropdownMenuItem(
                      value: type.typeId,
                      child: Text(type.label),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _typeId = value;
                        _validation = null;
                        _imported = null;
                        _error = null;
                      }),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: !_busy && _typeId != null ? _template : null,
            icon: const Icon(Icons.download),
            label: const Text('Download template'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _typeId == null ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(_filename ?? 'Select XLSX, XLS or CSV'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !_busy && _typeId != null && _bytes != null
                ? () => _run(persist: false)
                : null,
            child: const Text('Validate file'),
          ),
          if (_validation != null) ...[
            const SizedBox(height: 16),
            Text(
              'Validated ${_validation!.rows} rows — ${_validation!.ok ? 'valid' : 'errors found'}',
            ),
            for (final error in _validation!.errors)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                !_busy &&
                    _validation?.ok == true &&
                    _validation!.rows > 0 &&
                    _imported == null
                ? () => _run(persist: true)
                : null,
            child: const Text('Import validated items'),
          ),
          if (_imported != null) ...[
            const SizedBox(height: 16),
            Text(
              _imported!.ok
                  ? 'Imported: ${_imported!.created} created, ${_imported!.updated} updated.'
                  : 'Import failed.',
            ),
            for (final error in _imported!.errors)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

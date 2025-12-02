// lib/core/import/importer/import_inventory_screen.dart
import 'dart:typed_data';
import 'package:afyakit/core/import/importer/controllers/import_state.dart';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/shared/widgets/screen_header.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/core/import/importer/models/import_type_x.dart';
import 'controllers/import_controller.dart';

class ImportInventoryScreen extends ConsumerStatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  ConsumerState<ImportInventoryScreen> createState() =>
      _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends ConsumerState<ImportInventoryScreen> {
  ImportType _uploadType = ImportType.consumable;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(importControllerProvider);
    final ctrl = ref.read(importControllerProvider.notifier);

    final canValidate = st.fileName != null && !st.isLoading;
    final canImport =
        (st.validatedCount ?? 0) > 0 && !st.isLoading && st.fileName != null;

    return BaseScreen(
      scrollable: false,
      maxContentWidth: 720,
      header: const ScreenHeader('Import Inventory'),
      body: _buildBody(context, st, ctrl, canValidate, canImport),
    );
  }

  // ─────────────────────────── UI builders ───────────────────────────

  Widget _buildBody(
    BuildContext context,
    ImportState st,
    ImportController ctrl,
    bool canValidate,
    bool canImport,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTypeDropdown(),
            const SizedBox(height: 16),
            _buildFileRow(st, ctrl),
            const SizedBox(height: 12),
            _buildActionRow(context, ctrl, canValidate, canImport, st),
            const SizedBox(height: 20),
            const Divider(thickness: 1),
            const SizedBox(height: 12),
            const Text(
              'Need a template?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildTemplateButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<ImportType>(
      initialValue: _uploadType,
      decoration: const InputDecoration(
        labelText: 'Select Type',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: ImportType.values
          .map(
            (t) => DropdownMenuItem(value: t, child: Text(t.name.capitalize())),
          )
          .toList(),
      onChanged: (v) =>
          setState(() => _uploadType = v ?? ImportType.consumable),
    );
  }

  Widget _buildFileRow(ImportState st, ImportController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Text(
            st.fileName == null
                ? 'No file selected'
                : 'Selected: ${st.fileName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: st.isLoading ? null : ctrl.pickFile,
          icon: const Icon(Icons.upload_file),
          label: Text(st.isLoading ? 'Please wait…' : 'Choose File'),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    ImportController ctrl,
    bool canValidate,
    bool canImport,
    ImportState st,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // NEW: Match Preferences button → controller handles everything
        ElevatedButton.icon(
          onPressed: st.fileName != null && !st.isLoading
              ? () => ctrl.runMatcherFlow(context: context, type: _uploadType)
              : null,
          icon: const Icon(Icons.tune),
          label: const Text('Match Preferences'),
        ),
        ElevatedButton.icon(
          onPressed: canValidate
              ? () => ctrl.validate(type: _uploadType)
              : null,
          icon: const Icon(Icons.rule),
          label: Text(st.isLoading ? 'Validating…' : 'Validate'),
        ),
        ElevatedButton.icon(
          onPressed: canImport ? () => ctrl.persist(type: _uploadType) : null,
          icon: const Icon(Icons.file_download_done),
          label: Text(st.isLoading ? 'Importing…' : 'Import'),
        ),
        if (st.validatedCount != null)
          Chip(
            label: Text('Validated: ${st.validatedCount}'),
            avatar: const CircleAvatar(child: Icon(Icons.check, size: 16)),
          ),
      ],
    );
  }

  Widget _buildTemplateButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: ImportType.values
          .map(
            (type) => OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: Text('Download ${type.name.capitalize()} Template'),
              onPressed: () => _downloadTemplate(type),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────── File ops ───────────────────────────

  Future<void> _downloadTemplate(ImportType type) async {
    try {
      final bytes = await ref
          .read(importControllerProvider.notifier)
          .downloadTemplate(type: type);
      await _saveBytes('${type.name}_template.xlsx', bytes);
      SnackService.showSuccess(
        '${type.name.capitalize()} template downloaded.',
      );
    } catch (e) {
      SnackService.showError('Failed to download template: $e');
    }
  }

  Future<void> _saveBytes(String name, Uint8List bytes) async {
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: 'xlsx',
      mimeType: MimeType.other,
    );
  }
}

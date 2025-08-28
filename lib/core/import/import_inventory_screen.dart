import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/import/import_controller.dart';
import 'package:afyakit/core/import/import_template_service.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

class ImportInventoryScreen extends ConsumerStatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  ConsumerState<ImportInventoryScreen> createState() =>
      _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends ConsumerState<ImportInventoryScreen> {
  PlatformFile? _pickedFile;
  String? _fileName;
  String _uploadType = 'Consumable';
  final List<String> _uploadOptions = ['Consumable', 'Medication', 'Equipment'];

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importControllerProvider);

    return BaseScreen(
      scrollable: false,
      maxContentWidth: 800,
      header: const ScreenHeader('Import Inventory'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDropdown(),
              const SizedBox(height: 20),
              if (_fileName != null) _buildSelectedFileDisplay(),
              const SizedBox(height: 20),
              _buildPickFileButton(),
              const SizedBox(height: 12),
              if (_pickedFile != null)
                _buildImportButton(isLoading: importState is AsyncLoading),
              const SizedBox(height: 30),
              const Divider(thickness: 1),
              const SizedBox(height: 16),
              const Text(
                'Need a template?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildTemplateButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _uploadType,
      decoration: const InputDecoration(
        labelText: 'Select Type',
        border: OutlineInputBorder(),
      ),
      items: _uploadOptions
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (value) => setState(() => _uploadType = value ?? 'Consumable'),
    );
  }

  Widget _buildTemplateButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: ItemType.values.map((type) {
        return OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: Text('Download ${type.name.capitalize()} Template'),
          onPressed: () => _downloadTemplate(type),
        );
      }).toList(),
    );
  }

  Future<void> _downloadTemplate(ItemType type) async {
    try {
      final bytes = ImportTemplateService.generateTemplate(type);
      await FileSaver.instance.saveFile(
        name: '${type.name}_Template',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.other,
      );
      SnackService.showSuccess(
        '${type.name.capitalize()} template downloaded.',
      );
    } catch (e) {
      debugPrint('💥 Failed to generate template: $e');
      SnackService.showError('Failed to generate template: $e');
    }
  }

  Widget _buildSelectedFileDisplay() {
    return Text(
      'Selected File: $_fileName',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPickFileButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      onPressed: _pickFile,
      icon: const Icon(Icons.upload_file),
      label: const Text('Choose File'),
    );
  }

  Widget _buildImportButton({required bool isLoading}) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : _handleImportInventory,
      icon: const Icon(Icons.file_download_done),
      label: Text(isLoading ? 'Importing...' : 'Import Inventory'),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _fileName = _pickedFile!.name;
      });
      SnackService.showSuccess('File selected successfully!');
    }
  }

  Future<void> _handleImportInventory() async {
    final bytes = _pickedFile?.bytes;
    if (bytes == null) {
      SnackService.showError('No file selected or unreadable.');
      return;
    }

    final controller = ref.read(importControllerProvider.notifier);

    try {
      switch (_uploadType) {
        case 'Consumable':
          await controller.importConsumables(bytes);
          break;
        case 'Medication':
          await controller.importMedications(bytes);
          break;
        case 'Equipment':
          await controller.importEquipment(bytes);
          break;
      }

      setState(() {
        _pickedFile = null;
        _fileName = null;
      });
    } catch (e, stack) {
      debugPrint('💥 Import failed: $e\n$stack');
      SnackService.showError('Failed to import inventory: $e');
    }
  }
}

extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

import 'package:afyakit/features/import/import_controller.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportService {
  static Future<void> importInventory(WidgetRef ref) async {
    if (kIsWeb) {
      SnackService.showError('Importing is not supported on Web.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      final file = result?.files.first;
      final fileBytes = file?.bytes;

      if (fileBytes == null) {
        SnackService.showError('No file selected or unreadable.');
        return;
      }

      final controller = ref.read(importControllerProvider.notifier);
      controller.parseFile(fileBytes);

      final counts = controller.parsedCounts;
      final total = controller.totalCount;

      if (total == 0) {
        SnackService.showError('No valid inventory items found.');
        return;
      }

      final confirmed = await DialogService.confirm(
        title: 'Confirm Import',
        content:
            'Detected $total items:\n'
            '• ${counts['medications']} medications\n'
            '• ${counts['consumables']} consumables\n'
            '• ${counts['equipment']} equipment\n\nProceed with import?',
      );

      if (confirmed != true) return;

      await controller.commitImport();

      SnackService.showSuccess(
        'Successfully imported $total items:\n'
        '✓ ${counts['medications']} medications\n'
        '✓ ${counts['consumables']} consumables\n'
        '✓ ${counts['equipment']} equipment',
      );
    } catch (e, stack) {
      debugPrintStack(label: '❌ Inventory Import Failed', stackTrace: stack);
      SnackService.showError('Import failed: $e');
    }
  }
}

// backup_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/backup/backup_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final backupControllerProvider = StateNotifierProvider<BackupController, bool>((
  ref,
) {
  return BackupController();
});

class BackupController extends StateNotifier<bool> {
  BackupController() : super(false); // false = not loading

  Future<void> runBackup({
    required String selected,
    required bool includeSubcollections,
    required Map<String, String> labels,
  }) async {
    state = true;

    try {
      if (selected == 'All') {
        for (final path in labels.keys) {
          debugPrint('📦 Starting backup for $path');

          if (kIsWeb && includeSubcollections && path == 'stores') {
            debugPrint('🌐 Using manual store + batch backup (web)');
            await BackupService.backupCollection(
              collectionPath: path,
              includeSubcollections: true,
            );
          } else {
            await BackupService.backupCollection(
              collectionPath: path,
              includeSubcollections: !kIsWeb && includeSubcollections,
            );
          }
        }

        SnackService.showSuccess('✅ All collections backed up!');
      } else {
        debugPrint('📦 Starting backup for $selected');

        if (kIsWeb && includeSubcollections && selected == 'stores') {
          await BackupService.backupCollection(
            collectionPath: selected,
            includeSubcollections: true,
          );
        } else {
          await BackupService.backupCollection(
            collectionPath: selected,
            includeSubcollections: !kIsWeb && includeSubcollections,
          );
        }

        final label = labels[selected] ?? selected;
        SnackService.showSuccess('✅ $label backed up successfully!');
      }
    } catch (e) {
      SnackService.showError('❌ Backup failed: $e');
    } finally {
      state = false;
    }
  }
}

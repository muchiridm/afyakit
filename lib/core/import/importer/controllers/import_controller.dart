// lib/core/import/importer/controllers/import_controller.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

import '../inventory_import_service.dart';
import 'import_state.dart';

import 'package:afyakit/core/import/importer/models/import_type_x.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/import/preferences_matcher/preferences_matcher_controller.dart';
import 'package:afyakit/core/import/preferences_matcher/preferences_matcher_screen.dart';

final importControllerProvider =
    StateNotifierProvider.autoDispose<ImportController, ImportState>(
      (ref) => ImportController(ref),
    );

class ImportController extends StateNotifier<ImportState> {
  final Ref _ref;
  ImportController(this._ref) : super(ImportState.empty);

  PlatformFile? _pickedFile;
  Uint8List? get _bytes => _pickedFile?.bytes;

  // Expose bytes if needed elsewhere
  Future<Uint8List?> getSelectedBytes() async => _bytes;

  // Allow UI/flow to push mapping into state (used by runMatcherFlow)
  void applyGroupMap(Map<String, String> map) {
    state = state.copyWith(pendingGroupMap: Map<String, String>.from(map));
  }

  void setUnmappedGroups(List<String> groups) {
    state = state.copyWith(pendingUnmappedGroups: List<String>.from(groups));
  }

  // ─────────────────────────── File pick / validate / persist ─────────────────

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null ||
          result.files.isEmpty ||
          result.files.first.bytes == null) {
        SnackService.showError('No file selected or unreadable.');
        return;
      }
      _pickedFile = result.files.first;
      state = state.copyWith(
        fileName: _pickedFile!.name,
        validatedCount: null,
        pendingUnmappedGroups: const [],
        pendingGroupMap: const {},
      );
      SnackService.showSuccess('File selected successfully!');
    } catch (e, st) {
      if (kDebugMode) debugPrint('pickFile error: $e\n$st');
      SnackService.showError('Failed to pick file: $e');
    }
  }

  Future<void> validate({required ImportType type}) async {
    final bytes = _bytes;
    if (bytes == null) {
      SnackService.showError('No file selected.');
      return;
    }

    state = state.copyWith(isLoading: true, validatedCount: null);
    final svc = _ref.read(inventoryImportServiceProvider);

    final result = await svc.validate(
      type: type,
      filename: _pickedFile!.name,
      bytes: bytes,
    );

    state = state.copyWith(isLoading: false);

    if (!result.ok) {
      if ((result.errors ?? []).isNotEmpty) {
        await DialogService.alert(
          title: 'Import Errors',
          content: result.errors!.join('\n'),
        );
      } else {
        SnackService.showError(result.message ?? 'Validation failed.');
      }
      return;
    }

    final count = result.counts?[type.name] ?? 0;
    state = state.copyWith(validatedCount: count);

    if (count == 0) {
      SnackService.showError('No valid ${type.name} rows detected.');
      return;
    }
    SnackService.showSuccess('Validated $count ${type.name}(s).');
  }

  Future<void> persist({
    required ImportType type,
    Map<String, String>? groupMap, // optional override
  }) async {
    final bytes = _bytes;
    if (bytes == null) {
      SnackService.showError('No file selected.');
      return;
    }

    if ((state.validatedCount ?? 0) <= 0) {
      SnackService.showError('Please validate before importing.');
      return;
    }

    final confirmed = await DialogService.confirm(
      title: 'Confirm Import',
      content:
          'Validation passed.\nDetected ${state.validatedCount} ${type.name}(s).\n\nProceed to import?',
    );
    if (confirmed != true) return;

    state = state.copyWith(isLoading: true);
    final svc = _ref.read(inventoryImportServiceProvider);

    final result = await svc.persist(
      type: type,
      filename: _pickedFile!.name,
      bytes: bytes,
      // prefer explicit arg, else whatever we saved from matcher
      groupMap: (groupMap != null && groupMap.isNotEmpty)
          ? groupMap
          : (state.pendingGroupMap.isEmpty ? null : state.pendingGroupMap),
    );

    state = state.copyWith(isLoading: false);

    if (!result.ok) {
      final msg = (result.errors?.isNotEmpty ?? false)
          ? result.errors!.join('\n')
          : (result.message ?? 'Import failed during persist.');
      SnackService.showError(msg);
      return;
    }

    final imported = result.counts?[type.name] ?? 0;
    SnackService.showSuccess('Imported $imported ${type.name}(s).');

    _pickedFile = null;
    state = ImportState.empty;
  }

  Future<Uint8List> downloadTemplate({required ImportType type}) async {
    final svc = _ref.read(inventoryImportServiceProvider);
    return svc.downloadTemplate(type: type);
  }

  // ─────────────────────────── Matcher flow (controller-owned) ────────────────

  /// Opens the Preferences Matcher screen, lets the user reconcile values,
  /// then stores the GROUP mapping for the subsequent persist() call.
  Future<void> runMatcherFlow({
    required BuildContext context,
    required ImportType type,
  }) async {
    final bytes = _bytes;
    if (bytes == null || state.fileName == null) {
      SnackService.showError('No file selected.');
      return;
    }

    // 1) Try to introspect incoming values (safe to return {}).
    Map<ItemPreferenceField, Iterable<String>> incomingByField = const {};
    try {
      final svc = _ref.read(preferencesMatcherServiceProvider);
      incomingByField = await svc.introspectFromBytes(
        type: type,
        filename: state.fileName!,
        bytes: bytes,
      );
    } catch (_) {
      incomingByField = const {};
    }

    // 2) Always allow manual matching; open even if empty.
    final itemType = type.toItemType();
    final mapping = await Navigator.of(context)
        .push<Map<String, Map<String, String>>>(
          MaterialPageRoute(
            builder: (_) => PreferencesMatcherScreen(
              type: itemType,
              incomingByField: incomingByField,
            ),
            fullscreenDialog: true,
          ),
        );

    // Cancelled
    if (mapping == null) return;

    // 3) Keep only GROUP map for now (server supports group header).
    final groupMap = mapping['group'] ?? {};

    if (groupMap.isNotEmpty) {
      applyGroupMap(groupMap);
      SnackService.showSuccess('Preference mapping saved for this import.');
    } else {
      SnackService.showInfo('No group mapping selected.');
    }
  }
}

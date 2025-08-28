// lib/shared/services/dialog_service.dart

import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:flutter/material.dart';

/// Centralized dialogs with a safe context fallback.
/// Prefers an explicitly passed [context]; otherwise uses [navigatorKey.currentContext].
class DialogService {
  /// Resolve a usable BuildContext.
  static BuildContext? _ctx(BuildContext? context) {
    return context ?? navigatorKey.currentContext;
  }

  /// Confirm dialog that NEVER returns null.
  /// If no context can be resolved, returns false and logs.
  static Future<bool> confirm({
    BuildContext? context,
    required String title,
    required String content,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color confirmColor = Colors.redAccent,
    bool barrierDismissible = false,
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.confirm] No context available → false');
      return false;
    }

    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Simple alert dialog. No-op if context unavailable.
  static Future<void> alert({
    BuildContext? context,
    required String title,
    required String content,
    String buttonText = 'OK',
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.alert] No context available → skipping alert');
      return;
    }

    await showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  /// Text prompt. Returns trimmed string or null if cancelled/empty.
  static Future<String?> prompt({
    BuildContext? context,
    required String title,
    String? initialValue,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    bool isMultiline = false,
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.prompt] No context available → null');
      return null;
    }

    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            maxLines: isMultiline ? null : 1,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () {
                final input = controller.text.trim();
                Navigator.pop(context, input.isEmpty ? null : input);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return (result == null || result.trim().isEmpty) ? null : result.trim();
  }

  /// Store selection dialog.
  /// Returns the selected storeIds or null if cancelled.
  static Future<List<String>?> editStoreList(
    List<InventoryLocation> allStores,
    List<String> selectedStoreIds, {
    BuildContext? context,
    String title = 'Edit Store Access',
    String cancelText = 'Cancel',
    String saveText = 'Save',
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.editStoreList] No context available → null');
      return null;
    }

    final selected = Set<String>.from(selectedStoreIds);

    return showDialog<List<String>>(
      context: ctx,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allStores.length,
                  itemBuilder: (_, index) {
                    final store = allStores[index];
                    final isSelected = selected.contains(store.id);

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(store.name),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(store.id);
                          } else {
                            selected.remove(store.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(cancelText),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selected.toList()),
                  child: Text(saveText),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

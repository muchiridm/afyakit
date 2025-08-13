//lib/shared/services/dialog_service.dart

import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/main.dart'; // or wherever your navigatorKey is defined

class DialogService {
  static Future<bool?> confirm({
    required String title,
    required String content,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color confirmColor = Colors.redAccent,
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return null;

    return showDialog<bool>(
      context: ctx,
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
  }

  static Future<void> alert({
    required String title,
    required String content,
    String buttonText = 'OK',
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    return showDialog<void>(
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

  static Future<String?> prompt({
    required String title,
    String? initialValue,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    bool isMultiline = false,
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return null;

    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
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
  }

  static Future<List<String>?> editStoreList(
    List<InventoryLocation> allStores,
    List<String> selectedStoreIds,
  ) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return null;

    final selected = Set<String>.from(selectedStoreIds);

    return showDialog<List<String>>(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Store Access',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                    if (checked == true) {
                      selected.add(store.id);
                    } else {
                      selected.remove(store.id);
                    }
                    // 🔁 Force rebuild
                    (context as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

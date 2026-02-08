// lib/shared/services/dialog_service.dart

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:flutter/material.dart';

class DialogService {
  static BuildContext? _ctx(BuildContext? context) {
    return context ?? appNavigatorKey.currentContext;
  }

  static Future<T?> show<T>({
    BuildContext? context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.show] No context available → null');
      return null;
    }

    return showDialog<T>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

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
      useRootNavigator: true,
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
      useRootNavigator: true,
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

    final result = await showDialog<String?>(
      context: ctx,
      useRootNavigator: true,
      builder: (context) => _PromptDialog(
        title: title,
        initialValue: initialValue,
        confirmText: confirmText,
        cancelText: cancelText,
        isMultiline: isMultiline,
      ),
    );

    final trimmed = (result ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<List<String>?> multiSelect({
    BuildContext? context,
    required String title,
    required List<String> allIds,
    required String Function(String id) labelOf,
    required List<String> selectedIds,
    String cancelText = 'Cancel',
    String saveText = 'Save',
    bool barrierDismissible = true,
  }) async {
    final ctx = _ctx(context);
    if (ctx == null) {
      debugPrint('[DialogService.multiSelect] No context available → null');
      return null;
    }

    final selected = <String>{...selectedIds};

    return showDialog<List<String>>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
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
                  itemCount: allIds.length,
                  itemBuilder: (_, index) {
                    final id = allIds[index];
                    final isSelected = selected.contains(id);

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(labelOf(id)),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
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

  static Future<List<String>?> editStoreList(
    List<InventoryLocation> allStores,
    List<String> selectedStoreIds, {
    BuildContext? context,
    String title = 'Edit Store Access',
    String cancelText = 'Cancel',
    String saveText = 'Save',
  }) {
    final ids = allStores.map((s) => s.id).toList(growable: false);
    final byId = {for (final s in allStores) s.id: s.name};

    return multiSelect(
      context: context,
      title: title,
      allIds: ids,
      labelOf: (id) => byId[id] ?? id,
      selectedIds: selectedStoreIds,
      cancelText: cancelText,
      saveText: saveText,
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.isMultiline,
  });

  final String title;
  final String? initialValue;
  final String confirmText;
  final String cancelText;
  final bool isMultiline;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _ctl.text.trim();
    Navigator.pop(context, input.isEmpty ? null : input);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _ctl,
        maxLines: widget.isMultiline ? null : 1,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}

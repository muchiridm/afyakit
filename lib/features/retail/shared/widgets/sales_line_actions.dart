// lib/features/retail/sales/shared/widgets/sales_line_actions.dart

import 'package:flutter/foundation.dart';

@immutable
class SalesLineActions {
  const SalesLineActions({
    required this.index,
    required this.editable,
    required this.onEditName,
    required this.onEditQtyRate,
    required this.onRemoveLine,
  });

  final int index;
  final bool editable;

  final Future<void> Function(int index)? onEditName;
  final Future<void> Function(int index)? onEditQtyRate;
  final void Function(int index)? onRemoveLine;

  bool get canEdit => editable && (onEditQtyRate != null || onEditName != null);
  bool get canRemove => editable && onRemoveLine != null;

  Future<void> editRow() async {
    if (!canEdit) return;
    if (onEditQtyRate != null) return onEditQtyRate!(index);
    if (onEditName != null) return onEditName!(index);
  }

  Future<void> editNameOnly() async {
    if (!editable || onEditName == null) return;
    return onEditName!(index);
  }

  void remove() {
    if (!canRemove) return;
    onRemoveLine!(index);
  }
}

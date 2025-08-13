import 'package:afyakit/features/batches/screens/batch_editor_screen.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';

class BatchEditorArgs {
  final String tenantId;
  final BaseInventoryItem item;
  final BatchRecord? batch;
  final BatchEditorMode mode;

  BatchEditorArgs({
    required this.tenantId,
    required this.item,
    required this.mode,
    this.batch,
  });

  bool get isEditing => mode == BatchEditorMode.edit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchEditorArgs &&
          tenantId == other.tenantId &&
          item.id == other.item.id &&
          batch?.id == other.batch?.id &&
          mode == other.mode;

  @override
  int get hashCode =>
      tenantId.hashCode ^
      item.id.hashCode ^
      (batch?.id.hashCode ?? 0) ^
      mode.hashCode;
}

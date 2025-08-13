// inventory_editable_base.dart
import 'inventory_editable_controller.dart';

abstract class InventoryEditableBase implements InventoryEditableController {
  @override
  Future<void> setPackSize(String itemId, String value) async {}

  @override
  Future<void> setPackage(String itemId, String value) async {}
}

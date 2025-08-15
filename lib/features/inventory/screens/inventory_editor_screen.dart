import 'package:afyakit/features/inventory/controllers/forms/consumable_controller.dart';
import 'package:afyakit/features/inventory/controllers/forms/equipment_controller.dart';
import 'package:afyakit/features/inventory/controllers/forms/medication_controller.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_components/forms/consumable_form.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_components/forms/equipment_form.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_components/forms/medication_form.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_item_type.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventoryEditorScreen extends ConsumerStatefulWidget {
  final dynamic item;
  final ItemType? itemType;

  const InventoryEditorScreen({super.key, required this.item, this.itemType});

  @override
  ConsumerState<InventoryEditorScreen> createState() =>
      _InventoryEditorScreenState();
}

class _InventoryEditorScreenState extends ConsumerState<InventoryEditorScreen> {
  late final ItemType _resolvedType;

  @override
  void initState() {
    super.initState();
    _resolvedType = widget.item != null
        ? resolveItemType(widget.item)
        : widget.itemType ?? ItemType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(combinedUserProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading user: $e')),
      data: (user) {
        return BaseScreen(
          maxContentWidth: 800,
          scrollable: false,
          header: _buildHeader(user),
          body: _buildForm(),
        );
      },
    );
  }

  Widget _buildHeader(CombinedUser? user) {
    final canDelete = widget.item != null;

    return ScreenHeader(
      'Inventory Manager',
      trailing: canDelete ? _buildDeleteButton() : null,
    );
  }

  Widget _buildDeleteButton() {
    final itemId = widget.item?.id;
    if (itemId == null) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
      tooltip: 'Delete Item',
      onPressed: () {
        switch (_resolvedType) {
          case ItemType.medication:
            ref.read(medicationControllerProvider).delete(itemId);
            break;
          case ItemType.consumable:
            ref.read(consumableControllerProvider).delete(itemId);
            break;
          case ItemType.equipment:
            ref.read(equipmentControllerProvider).delete(itemId);
            break;
          case ItemType.unknown:
            SnackService.showError('❌ Cannot delete unknown item type.');
            break;
        }
      },
    );
  }

  Widget _buildForm() {
    return switch (_resolvedType) {
      ItemType.medication =>
        widget.item != null
            ? MedicationForm(item: widget.item as MedicationItem)
            : const MedicationForm(),

      ItemType.consumable =>
        widget.item != null
            ? ConsumableForm(item: widget.item as ConsumableItem)
            : const ConsumableForm(),

      ItemType.equipment =>
        widget.item != null
            ? EquipmentForm(item: widget.item as EquipmentItem)
            : const EquipmentForm(),

      ItemType.unknown => const Center(
        child: Text('⚠️ Unknown item type. Cannot render form.'),
      ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_user_providers.dart';

import 'package:afyakit/features/inventory/items/controllers/forms/consumable_controller.dart';
import 'package:afyakit/features/inventory/items/controllers/forms/equipment_controller.dart';
import 'package:afyakit/features/inventory/items/controllers/forms/medication_controller.dart';

import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';

import 'package:afyakit/features/inventory/items/screens/inventory_editor_components/forms/consumable_form.dart';
import 'package:afyakit/features/inventory/items/screens/inventory_editor_components/forms/equipment_form.dart';
import 'package:afyakit/features/inventory/items/screens/inventory_editor_components/forms/medication_form.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_item_type.dart';

class InventoryEditorScreen extends ConsumerStatefulWidget {
  final Object? item;
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
    final sessionAsync = ref.watch(currentUserProvider);

    return sessionAsync.when(
      loading: () => const AppPage(
        scrollable: false,
        maxWidth: 800,
        header: AppHeader(title: 'Inventory Manager'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppPage(
        scrollable: false,
        maxWidth: 800,
        header: const AppHeader(title: 'Inventory Manager'),
        body: Center(child: Text('Error loading user: $e')),
      ),
      data: (user) {
        return AppPage(
          maxWidth: 800,
          scrollable: false,
          header: _buildHeader(user),
          body: _buildForm(),
        );
      },
    );
  }

  Widget _buildHeader(AuthUser? user) {
    final canDelete = widget.item != null;

    return AppHeader(
      title: 'Inventory Manager',
      trailing: canDelete ? _buildDeleteButton() : null,
    );
  }

  Widget _buildDeleteButton() {
    final itemId = _extractItemId(widget.item);
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

  /// Avoids dynamic. If your base item type shares `id`, replace this with a
  /// proper interface / base class cast.
  String? _extractItemId(Object? item) {
    if (item == null) return null;
    // Common case: your item models have an `id` getter.
    // This is still runtime-based but doesn't poison the whole widget with `dynamic`.
    final obj = item;
    try {
      // ignore: avoid_dynamic_calls
      final id = (obj as dynamic).id as Object?;
      return id is String && id.trim().isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
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

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_view/widgets/inventory_item_tile_components/inventory_tile_header.dart';
import 'package:afyakit/features/inventory_view/widgets/inventory_item_tile_components/batch_row.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_screen.dart';
import 'package:afyakit/features/inventory_view/utils/inventory_mode_enum.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/features/auth_users/user_operations/providers/current_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventoryItemTile extends ConsumerStatefulWidget {
  final dynamic item;
  final String group;
  final String name;

  final String? description;
  final String? brandName;
  final String? strength;
  final String? size;
  final String? formulation;
  final List<String>? route;
  final String? packSize;
  final String? unit;
  final String? package;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;

  final List<BatchRecord> batches;
  final List<InventoryLocation>? stores;

  final bool editable;
  final bool selectable;
  final bool enableSelectionCart;
  final InventoryMode mode;

  final Map<String, int>? batchQuantities;
  final void Function(BatchRecord, int)? onBatchQtyChange;
  final void Function(String itemId)? onAddToCart;

  final VoidCallback? onAddBatch;

  const InventoryItemTile({
    super.key,
    required this.item,
    required this.group,
    required this.name,
    required this.batches,
    required this.editable,
    required this.selectable,
    required this.mode, // 👈 make required
    this.description,
    this.brandName,
    this.strength,
    this.size,
    this.formulation,
    this.route,
    this.packSize,
    this.unit,
    this.package,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.enableSelectionCart = false,
    this.batchQuantities,
    this.onBatchQtyChange,
    this.onAddToCart,
    this.onAddBatch,
    this.stores,
  });

  @override
  ConsumerState<InventoryItemTile> createState() => _InventoryItemTileState();
}

class _InventoryItemTileState extends ConsumerState<InventoryItemTile> {
  bool _expanded = false;

  bool get isSelected =>
      widget.enableSelectionCart &&
      (widget.batchQuantities?.values.any((qty) => qty > 0) ?? false);

  @override
  Widget build(BuildContext context) {
    return _buildInventoryCard();
  }

  Widget _buildInventoryCard() {
    final totalStock = widget.batches.fold<int>(
      0,
      (sum, b) => sum + b.quantity,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.teal.shade400, width: 1.3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InventoryTileHeader(
                genericName: widget.name,
                subtitle: _buildSubtitle(),
                totalStock: totalStock,
                canEdit: widget.editable,
                onEdit: _navigateToEditItem,
              ),
              if (_expanded) ..._buildExpandableContent(stores: widget.stores),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandableContent({
    required List<InventoryLocation>? stores,
  }) {
    if (stores == null) return [const Text('Loading store data...')];

    final rows = <Widget>[];
    final user = ref.watch(currentUserProvider).valueOrNull;

    final isStockIn = widget.mode.isStockIn;
    final isStockOut = widget.mode.isStockOut;

    for (final b in widget.batches) {
      final canEdit = isStockIn && (user?.canEditBatch(b) ?? false);
      final canSelect =
          isStockOut; // ← ✅ Always show quantity adjust in Stock Out

      rows.add(
        BatchRow(
          batch: b,
          editable: canEdit, // ✏️ Only in Stock In
          selectable: canSelect, // 🔢 Always in Stock Out
          item: widget.item,
          itemType: widget.item.type,
          mode: widget.mode,
          stores: stores,
        ),
      );
    }

    final canAdd = isStockIn && (user?.isManagerOrAdmin ?? false);

    if (canAdd) {
      rows.add(
        _buildAddBatchButton(
          widget.onAddBatch ??
              () => debugPrint('⚠️ onAddBatch not provided for ${widget.name}'),
        ),
      );
    }

    return [const Divider(height: 20), ...rows];
  }

  void _navigateToEditItem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryEditorScreen(item: widget.item),
      ),
    );
  }

  Widget _buildAddBatchButton(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add, size: 18, color: Colors.teal),
          label: const Text(
            'Add Batch',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.teal,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];

    void add(String? val) {
      if (val != null && val.trim().isNotEmpty) {
        parts.add(val.trim());
      }
    }

    add(widget.group);
    if (widget.brandName != null) parts.add('(${widget.brandName})');
    add(widget.description);
    add(widget.strength);
    add(widget.size);
    add(widget.formulation);
    if (widget.route?.isNotEmpty ?? false) parts.add(widget.route!.join(', '));
    add(widget.packSize);
    add(widget.unit);
    add(widget.package);
    add(widget.model);
    add(widget.manufacturer);
    add(widget.serialNumber);

    return parts.isEmpty ? 'No details available' : parts.join(' · ');
  }
}

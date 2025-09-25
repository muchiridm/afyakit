import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';

class InventorySpeedDial extends StatelessWidget {
  final void Function(ItemType type)? onAdd;

  const InventorySpeedDial({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Colors.teal.shade600,
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.redAccent,
      activeForegroundColor: Colors.white,
      overlayOpacity: 0.1,
      spacing: 12,
      spaceBetweenChildren: 8,
      elevation: 10,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.medication, color: Colors.white),
          backgroundColor: Colors.indigo,
          label: 'Add Medication',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          labelBackgroundColor: Colors.white,
          onTap: () => onAdd?.call(ItemType.medication),
        ),
        SpeedDialChild(
          child: const Icon(Icons.inventory_2, color: Colors.white),
          backgroundColor: Colors.orange,
          label: 'Add Consumable',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          labelBackgroundColor: Colors.white,
          onTap: () => onAdd?.call(ItemType.consumable),
        ),
        SpeedDialChild(
          child: const Icon(Icons.devices, color: Colors.white),
          backgroundColor: Colors.grey,
          label: 'Add Equipment',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          labelBackgroundColor: Colors.white,
          onTap: () => onAdd?.call(ItemType.equipment),
        ),
      ],
    );
  }
}

import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

class LocationPreferencesScreen extends ConsumerStatefulWidget {
  final InventoryLocationType type;

  const LocationPreferencesScreen({super.key, required this.type});

  @override
  ConsumerState<LocationPreferencesScreen> createState() =>
      _LocationPreferencesState();
}

class _LocationPreferencesState
    extends ConsumerState<LocationPreferencesScreen> {
  final _inputController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(inventoryLocationProvider(widget.type));
    final controller = ref.read(
      inventoryLocationProvider(widget.type).notifier,
    );

    return BaseScreen(
      scrollable: false,
      maxContentWidth: 600,
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader(_getTitle(widget.type)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: locationState.when(
          data: (locations) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationList(locations, controller),
              const SizedBox(height: 24),
              _buildInputField(controller),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  String _getTitle(InventoryLocationType type) => switch (type) {
    InventoryLocationType.store => 'Stores',
    InventoryLocationType.source => 'Delivery Sources',
    InventoryLocationType.dispensary => 'Dispensaries',
  };

  Widget _buildLocationList(
    List<InventoryLocation> locations,
    InventoryLocationController controller,
  ) {
    if (locations.isEmpty) {
      return Text('No ${_getTitle(widget.type).toLowerCase()} added yet.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: locations
          .map(
            (location) => Chip(
              label: Text(location.name),
              deleteIcon: const Icon(Icons.close),
              onDeleted: () => controller.delete(location.id),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInputField(InventoryLocationController controller) {
    final placeholder = widget.type.asString; // matches enum string

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            decoration: InputDecoration(
              hintText: 'Add new $placeholder...',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty) {
                await controller.add(value.trim());
                _inputController.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final text = _inputController.text.trim();
            if (text.isNotEmpty) {
              await controller.add(text);
              _inputController.clear();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

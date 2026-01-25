import 'package:afyakit/features/inventory/locations/screens/inventory_location_preferences_screen.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 600,
      scrollable: false,
      header: const AppHeader(title: 'Location Settings'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _navButton(
              context,
              icon: Icons.store,
              label: 'Manage Stores',
              type: InventoryLocationType.store,
            ),
            const SizedBox(height: 16),
            _navButton(
              context,
              icon: Icons.local_shipping,
              label: 'Manage Sources',
              type: InventoryLocationType.source,
            ),
            const SizedBox(height: 16),
            _navButton(
              context,
              icon: Icons.medical_services,
              label: 'Manage Dispensaries',
              type: InventoryLocationType.dispensary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required InventoryLocationType type,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationPreferencesScreen(type: type),
          ),
        );
      },
    );
  }
}

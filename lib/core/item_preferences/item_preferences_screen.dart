import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/item_preferences/item_preferences_controller.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/core/inventory_view/widgets/inventory_item_tile_components/editable_chip_list.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

class ItemPreferencesScreen extends ConsumerStatefulWidget {
  const ItemPreferencesScreen({super.key});

  @override
  ConsumerState<ItemPreferencesScreen> createState() =>
      _ItemPreferencesScreenState();
}

class _ItemPreferencesScreenState extends ConsumerState<ItemPreferencesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  final Map<ItemType, List<ItemPreferenceField>> fieldsByType = {
    ItemType.medication: [
      ItemPreferenceField.group,
      ItemPreferenceField.formulation,
      ItemPreferenceField.route,
    ],
    ItemType.consumable: [
      ItemPreferenceField.group,
      ItemPreferenceField.package,
      ItemPreferenceField.unit,
    ],
    ItemType.equipment: [ItemPreferenceField.group],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ItemType.values.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      scrollable: false,
      maxContentWidth: 800,
      header: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('Item Preferences'),
      ),
      body: Column(
        children: [
          _buildTabs(),
          const SizedBox(height: 8),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Medication'),
        Tab(text: 'Consumable'),
        Tab(text: 'Equipment'),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPreferencesSection(ItemType.medication),
        _buildPreferencesSection(ItemType.consumable),
        _buildPreferencesSection(ItemType.equipment),
      ],
    );
  }

  Widget _buildPreferencesSection(ItemType type) {
    final fields = fieldsByType[type] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((field) {
          final key = PreferenceKey(type, field);
          final state = ref.watch(itemPreferenceControllerProvider(key));
          final controller = ref.read(
            itemPreferenceControllerProvider(key).notifier,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalize(field.name),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    state.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error: $e'),
                      data: (values) {
                        final labelToIdMap = {for (final v in values) v: v};
                        return EditableChipList(
                          labelToId: labelToIdMap,
                          onAdd: controller.add,
                          onRemove: controller.remove,
                          hintText: 'Add new ${field.name}...',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}

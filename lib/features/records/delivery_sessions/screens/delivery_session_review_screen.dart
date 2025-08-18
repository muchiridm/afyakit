import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';
import 'package:afyakit/features/records/delivery_sessions/models/view_models/delivery_review_summary.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// 🔍 Helper to resolve store/dispensary IDs to human-readable names

class DeliverySessionReviewScreen extends ConsumerWidget {
  const DeliverySessionReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(deliverySessionControllerProvider);
    final tenantId = ref.watch(tenantIdProvider);

    // ✅ Stores & dispensaries are already plain lists
    final stores = ref.watch(allStoresProvider);
    final dispensaries = ref.watch(allDispensariesProvider);

    if (!session.isActive || session.deliveryId == null) {
      return const BaseScreen(
        header: ScreenHeader('Delivery Preview'),
        body: Center(child: Text('⚠️ No active delivery session found.')),
      );
    }

    return FutureBuilder<DeliveryReviewSummary?>(
      future: ref
          .read(deliverySessionControllerProvider.notifier)
          .getReviewSummary(tenantId: tenantId, state: session, ref: ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BaseScreen(
            header: ScreenHeader('Delivery Preview'),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return BaseScreen(
            header: const ScreenHeader('Delivery Preview'),
            body: Center(child: Text('❌ Error: ${snapshot.error}')),
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const BaseScreen(
            header: ScreenHeader('Delivery Preview'),
            body: Center(child: Text('No batches found in this delivery.')),
          );
        }

        return BaseScreen(
          scrollable: true,
          header: ScreenHeader('Preview: ${summary.summary.deliveryId}'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMeta(summary),
              const SizedBox(height: 16),
              ...summary.items.map(
                (item) => ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    'Qty: ${item.quantity} · '
                    'Store: ${resolveLocationName(item.store, stores, dispensaries)} · '
                    'Type: ${item.type}',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Confirm & Save'),
                  onPressed: () async {
                    final controller = ref.read(
                      deliverySessionControllerProvider.notifier,
                    );
                    final success = await controller.endDeliverySession();
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeta(DeliveryReviewSummary summary) {
    final dateStr = DateFormat('yyyy-MM-dd').format(summary.summary.date);
    final enteredBy = summary.enteredBy;
    final sourceSummary = summary.sourceSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🗓️ Date: $dateStr'),
        Text('🧑‍💼 Entered by: $enteredBy'),
        Text('🏢 Source: $sourceSummary'),
        Text('📦 Items: ${summary.totalItems}'),
        Text('📊 Total Quantity: ${summary.totalQuantity}'),
      ],
    );
  }
}

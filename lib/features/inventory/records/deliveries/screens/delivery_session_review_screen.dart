import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/batches/providers/batch_records_stream_provider.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_controller.dart';
import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_engine.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_review_summary.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';

class DeliverySessionReviewScreen extends ConsumerWidget {
  const DeliverySessionReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // STATE comes from the engine
    final session = ref.watch(deliverySessionEngineProvider);
    final tenantId = ref.watch(tenantIdProvider);

    // Stores & dispensaries (plain lists)
    final stores = ref.watch(allStoresProvider);
    final dispensaries = ref.watch(allDispensariesProvider);

    if (!session.isActive || session.deliveryId == null) {
      return const AppPage(
        scrollable: false,
        header: AppHeader(title: 'Delivery Preview'),
        body: Center(child: Text('⚠️ No active delivery session found.')),
      );
    }

    // 1) Wait for the batches stream first (avoid false "empty")
    final batchesAsync = ref.watch(batchRecordsStreamProvider(tenantId));
    return batchesAsync.when(
      loading: () => const AppPage(
        scrollable: false,
        header: AppHeader(title: 'Delivery Preview'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const AppPage(
        scrollable: false,
        header: AppHeader(title: 'Delivery Preview'),
        body: Center(child: Text('❌ Batches failed to load')),
      ),
      data: (batches) {
        final target = session.deliveryId!;
        final linked = batches
            .where((b) => (b.deliveryId ?? '').trim() == target)
            .toList();

        // Debug once: see what we’re linking
        debugPrint(
          '🔗 DeliveryPreview link-check → delivery=$target '
          'total=${batches.length} linked=${linked.length} '
          'sample=${linked.take(3).map((b) => '${b.id}:${b.deliveryId}').toList()}',
        );

        if (linked.isEmpty) {
          return AppPage(
            scrollable: false,
            header: const AppHeader(title: 'Delivery Preview'),
            body: Center(
              child: Text(
                'No batches found in this delivery ($target).\n'
                'Add a batch or ensure new batches carry deliveryId.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // 2) We have linked batches → build the proper summary via controller (actions)
        final ctrl = ref.read(deliverySessionControllerProvider);

        return FutureBuilder<DeliveryReviewSummary?>(
          future: ctrl.review(ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppPage(
                scrollable: false,
                header: AppHeader(title: 'Delivery Preview'),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const AppPage(
                scrollable: false,
                header: AppHeader(title: 'Delivery Preview'),
                body: Center(child: Text('❌ Failed to build summary')),
              );
            }

            final summary = snapshot.data;
            if (summary == null) {
              return const AppPage(
                scrollable: false,
                header: AppHeader(title: 'Delivery Preview'),
                body: Center(
                  child: Text(
                    'No batches found after summary build. Try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return AppPage(
              scrollable: true,
              header: AppHeader(
                title: 'Preview: ${summary.summary.deliveryId}',
              ),
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
                        final ok = await ctrl.end();
                        if (ok && context.mounted) {
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

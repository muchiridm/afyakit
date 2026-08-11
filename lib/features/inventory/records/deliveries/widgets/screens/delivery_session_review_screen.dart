// lib/features/inventory/records/deliveries/widgets/screens/delivery_session_review_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final session = ref.watch(deliverySessionEngineProvider);

    final stores = ref.watch(allStoresProvider);

    final dispensaries = ref.watch(allDispensariesProvider);

    final deliveryId = session.deliveryId?.trim() ?? '';

    if (deliveryId.isEmpty) {
      return const AppPage(
        scrollable: false,
        header: AppHeader(title: 'Delivery Preview'),
        body: Center(child: Text('⚠️ No active delivery session found.')),
      );
    }

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
          final error = snapshot.error;

          debugPrint(
            '❌ Delivery review failed '
            'for $deliveryId: $error',
          );

          return AppPage(
            scrollable: false,
            header: const AppHeader(title: 'Delivery Preview'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to build delivery summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error?.toString() ?? 'Unknown error',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final summary = snapshot.data;

        if (summary == null) {
          return AppPage(
            scrollable: false,
            header: const AppHeader(title: 'Delivery Preview'),
            body: Center(
              child: Text(
                'No batches found in this delivery '
                '($deliveryId).',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return AppPage(
          scrollable: true,
          header: AppHeader(title: 'Preview: ${summary.summary.deliveryId}'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMeta(summary),
              const SizedBox(height: 16),
              ...summary.items.map(
                (item) => ListTile(
                  leading: Icon(
                    item.isEdited
                        ? Icons.edit_outlined
                        : Icons.add_circle_outline,
                    color: item.isEdited ? Colors.orange : Colors.teal,
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    'Qty: ${item.quantity} · '
                    'Store: ${resolveLocationName(item.store, stores, dispensaries)} · '
                    'Type: ${item.type}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(item.actionLabel),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    // Navigate to the batch detail/editor here.
                  },
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

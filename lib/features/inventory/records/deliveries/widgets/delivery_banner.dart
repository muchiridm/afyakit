// lib/features/inventory/records/deliveries/widgets/delivery_banner.dart

import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_record_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_engine.dart';
import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/screens/delivery_session_review_screen.dart';

class DeliveryBanner extends ConsumerWidget {
  const DeliveryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(deliveryBannerVisibleProvider);

    if (!visible) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(deliverySessionEngineProvider);

    return _buildBannerContainer(context: context, session: session);
  }

  Widget _buildBannerContainer({
    required BuildContext context,
    required DeliverySessionState session,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final text = _buildSessionText(session);

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildReviewButton(context),
                ),
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(child: text),
              const SizedBox(width: 12),
              _buildReviewButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionText(DeliverySessionState session) {
    final id = (session.deliveryId ?? '').trim();

    final source = (session.lastSource ?? '').trim();

    final store = (session.lastStoreId ?? '').trim();

    final parts = <String>[
      if (id.isNotEmpty) 'Ongoing Delivery: $id' else 'Ongoing Delivery',
      if (store.isNotEmpty) ' • Store: $store',
      if (source.isNotEmpty) ' • Source: $source',
    ];

    return Text(parts.join(), maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  Widget _buildReviewButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DeliverySessionReviewScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      child: const Text('Review & Save'),
    );
  }
}

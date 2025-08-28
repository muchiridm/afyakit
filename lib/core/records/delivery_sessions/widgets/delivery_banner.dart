// lib/features/records/delivery_sessions/widgets/delivery_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/records/delivery_sessions/controllers/delivery_session_engine.dart';
import 'package:afyakit/core/records/delivery_sessions/controllers/delivery_session_state.dart';
import 'package:afyakit/core/records/delivery_sessions/screens/delivery_session_review_screen.dart';
import 'package:afyakit/core/records/delivery_sessions/providers/delivery_banner_provider.dart';
// 🔗 use the active temp-session stream to “prime” the engine before navigating
import 'package:afyakit/core/records/delivery_sessions/providers/active_delivery_session_provider.dart';

class DeliveryBanner extends ConsumerWidget {
  const DeliveryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate visibility from Firestore so it won’t be “sticky”
    final visibleAsync = ref.watch(deliveryBannerVisibleProvider);

    return visibleAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (visible) {
        if (!visible) return const SizedBox.shrink();

        // For display text we can read the engine (cheap); it’s OK if null.
        final session = ref.watch(deliverySessionEngineProvider);
        return _buildBannerContainer(
          context: context,
          ref: ref,
          session: session,
        );
      },
    );
  }

  Widget _buildBannerContainer({
    required BuildContext context,
    required WidgetRef ref,
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
                  child: _buildReviewButton(context, ref),
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
              _buildReviewButton(context, ref),
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

  Widget _buildReviewButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // 🔄 Make sure the engine is pointing at the active temp session
        final active = await ref.read(activeDeliverySessionProvider.future);
        if (active != null) {
          await ref
              .read(deliverySessionEngineProvider.notifier)
              .ensureActive(
                enteredByName: active.enteredByName ?? active.enteredByEmail,
                enteredByEmail: active.enteredByEmail,
                source: active.lastSource ?? '',
                storeId: active.lastStoreId ?? '',
              );
        }

        // ➡️ then navigate to the review screen
        // (engine is primed so the screen won’t show “No active session”)
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DeliverySessionReviewScreen(),
            ),
          );
        }
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

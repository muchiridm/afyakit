import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';
import 'package:afyakit/features/records/delivery_sessions/screens/delivery_session_review_screen.dart';

class DeliveryBanner extends ConsumerWidget {
  const DeliveryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(deliverySessionControllerProvider);
    if (session.deliveryId == null) return const SizedBox.shrink();

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
          final isNarrow = constraints.maxWidth < 400;
          return isNarrow
              ? Column(
                  // Fallback for narrow screens
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSessionText(session)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildReviewButton(context),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSessionText(session)),
                    const SizedBox(width: 12),
                    _buildReviewButton(context),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildSessionText(DeliverySessionState session) {
    return Text('Ongoing Delivery: ${session.deliveryId}');
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

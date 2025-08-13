import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/features/records/delivery_sessions/widgets/delivery_banner.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/stock/batch_records_stream_provider.dart';
import 'package:afyakit/users/widgets/logout_button.dart';

class HomeHeader extends ConsumerWidget {
  final dynamic session;

  const HomeHeader({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final asyncBatches = ref.watch(batchRecordsStreamProvider(tenantId));

    final hasBatchesForSession = asyncBatches.when(
      data: (batches) =>
          session.isActive &&
          session.deliveryId != null &&
          batches.any((b) => b.deliveryId == session.deliveryId),
      loading: () => false,
      error: (_, __) => false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const ScreenHeader(
            'Danab TMC',
            showBack: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(width: 8), LogoutButton()],
            ),
          ),
          if (hasBatchesForSession)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: DeliveryBanner(),
            ),
        ],
      ),
    );
  }
}

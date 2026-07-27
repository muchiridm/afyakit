// lib/core/home/activities/shared/staff_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/activities/feed/activity_feed_adapter.dart';
import 'package:afyakit/core/home/activities/feed/activity_feed_providers.dart';
import 'package:afyakit/core/home/activities/shared/latest_activity_panel.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_record_tile.dart';
import 'package:afyakit/features/inventory/records/issues/providers/issue_streams_provider.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/issue_record_tile.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({
    super.key,
    this.maxItems = 10,
    this.onTitleTap,
    this.title = 'Latest Activity',
    this.emptyText = 'No recent staff activity yet.',
  });

  final int? maxItems;
  final VoidCallback? onTitleTap;
  final String title;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantId = ref.watch(tenantIdProvider);
    final bool inventoryEnabled = ref.watch(tenantInventoryEnabledProvider);

    final _ActivityResult inventoryResult = inventoryEnabled
        ? _watchInventoryActivity(ref, tenantId)
        : const _ActivityResult.empty();

    final activityAsync = ref.watch(staffActivityFeedProvider);

    final List<ActivityEntry> feedEntries = ActivityFeedAdapter.fromFeed(
      activityAsync.valueOrNull ?? const [],
      onTapForActivity: (activity) {
        final String? paymentId = activity.paymentId?.trim();
        final String? invoiceId = activity.invoiceId?.trim();

        if (_hasText(paymentId) && _hasText(invoiceId)) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PaymentDetailScreen(
                invoiceId: invoiceId!,
                paymentId: paymentId!,
                currencyCode: activity.currencyCode ?? 'KES',
                customerName: activity.subtitle,
                invoiceNumber: activity.invoiceNumber,
                canManagePayments: true,
              ),
            ),
          );
        }

        if (_hasText(invoiceId)) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InvoiceDetailScreen(
                invoiceId: invoiceId!,
                forceStaffWorkspace: true,
              ),
            ),
          );
        }

        final String? quoteId = activity.quoteId?.trim();

        if (_hasText(quoteId)) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => QuoteDetailScreen(
                quoteId: quoteId!,
                forceStaffWorkspace: true,
              ),
            ),
          );
        }

        final bool isPatientActivity = activity.type.startsWith('patient_');

        if (isPatientActivity) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const ProfilesScreen(allowExplicitContactLink: true),
            ),
          );
        }

        final bool isContactActivity = activity.type.startsWith('contact_');

        if (isContactActivity) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ContactsScreen()),
          );
        }

        return null;
      },
    );

    final List<ActivityEntry> entries = <ActivityEntry>[
      ...inventoryResult.entries,
      ...feedEntries,
    ]..sort((ActivityEntry a, ActivityEntry b) => b.date.compareTo(a.date));

    return LatestActivityPanel(
      title: title,
      icon: Icons.notifications_none,
      loading: inventoryResult.loading || activityAsync.isLoading,
      hasError: inventoryResult.hasError || activityAsync.hasError,
      errorText: 'Could not load activity.',
      entries: entries,
      emptyText: emptyText,
      maxItems: maxItems,
      onTitleTap: onTitleTap,
    );
  }

  _ActivityResult _watchInventoryActivity(WidgetRef ref, String tenantId) {
    final issuesAsync = ref.watch(issuesStreamProvider(tenantId));
    final deliveriesAsync = ref.watch(deliveryRecordsStreamProvider(tenantId));

    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );

    final dispensariesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.dispensary),
    );

    final bool loading =
        issuesAsync.isLoading ||
        deliveriesAsync.isLoading ||
        storesAsync.isLoading ||
        dispensariesAsync.isLoading;

    final bool hasError =
        issuesAsync.hasError ||
        deliveriesAsync.hasError ||
        storesAsync.hasError ||
        dispensariesAsync.hasError;

    final stores = storesAsync.valueOrNull ?? const [];
    final dispensaries = dispensariesAsync.valueOrNull ?? const [];

    final List<ActivityEntry> entries = <ActivityEntry>[
      for (final issue in issuesAsync.valueOrNull ?? const [])
        ActivityEntry(
          date: issue.dateIssuedOrReceived ?? issue.dateRequested,
          widget: IssueRecordTile(
            issue: issue,
            stores: stores,
            dispensaries: dispensaries,
          ),
        ),
      for (final delivery in deliveriesAsync.valueOrNull ?? const [])
        ActivityEntry(
          date: delivery.date,
          widget: DeliveryRecordTile(record: delivery, stores: stores),
        ),
    ]..sort((ActivityEntry a, ActivityEntry b) => b.date.compareTo(a.date));

    return _ActivityResult(
      loading: loading,
      hasError: hasError,
      entries: entries,
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _ActivityResult {
  const _ActivityResult({
    required this.loading,
    required this.hasError,
    required this.entries,
  });

  const _ActivityResult.empty()
    : loading = false,
      hasError = false,
      entries = const <ActivityEntry>[];

  final bool loading;
  final bool hasError;
  final List<ActivityEntry> entries;
}

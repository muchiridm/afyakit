// lib/core/home/activities/shared/staff_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';

import 'package:afyakit/features/home/activities/feed/activity_feed_adapter.dart';
import 'package:afyakit/features/home/activities/feed/activity_feed_providers.dart';
import 'package:afyakit/features/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/features/home/activities/shared/latest_activity_panel.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/inventory_deliveries_screen.dart';
import 'package:afyakit/features/inventory/records/issues/inventory_issues_screen.dart';

import 'package:afyakit/features/records/health_profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/records/native_contacts/widgets/native_contacts_screen.dart';

import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({
    super.key,
    this.maxItems = 5,
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
    final appId = ref.watch(appIdProvider);
    final activityAsync = ref.watch(staffActivityFeedProvider);

    // null = all configured location types.
    final locationsAsync = ref.watch(inventoryLocationsProvider(null));

    final locations = locationsAsync.valueOrNull ?? const <InventoryLocation>[];

    final entries = ActivityFeedAdapter.fromFeed(
      activityAsync.valueOrNull ?? const [],
      onTapForActivity: (activity) =>
          _onTapForActivity(context, activity, appId),
      subtitleForActivity: (activity) =>
          _subtitleForActivity(activity, locations),
    ).toList()..sort((a, b) => b.date.compareTo(a.date));

    return LatestActivityPanel(
      title: title,
      icon: Icons.notifications_none,
      loading: activityAsync.isLoading,
      hasError: activityAsync.hasError,
      errorText: 'Could not load activity.',
      entries: entries,
      emptyText: emptyText,
      maxItems: maxItems,
      onTitleTap: onTitleTap,
    );
  }

  // ─────────────────────────────────────────────
  // Activity navigation
  // ─────────────────────────────────────────────

  VoidCallback? _onTapForActivity(
    BuildContext context,
    ActivityFeedRecord activity,
    String appId,
  ) {
    switch (activity.entity.type) {
      case ActivityEntityType.payment:
        final invoice = activity.relatedEntity(ActivityEntityType.invoice);

        final paymentId = activity.entity.id.trim();

        if (!_hasText(paymentId) || invoice == null || !_hasText(invoice.id)) {
          return null;
        }

        return () => _navigate(
          context,
          PaymentDetailScreen(
            invoiceId: invoice.id,
            paymentId: paymentId,
            currencyCode: activity.currencyCode ?? 'KES',
            customerName: activity.subtitle,
            invoiceNumber: invoice.label,
            canManagePayments: true,
          ),
        );

      case ActivityEntityType.invoice:
        final invoiceId = activity.entity.id.trim();

        if (invoiceId.isEmpty) return null;

        return () => _navigate(
          context,
          InvoiceDetailScreen(invoiceId: invoiceId, forceStaffWorkspace: true),
        );

      case ActivityEntityType.quote:
        final quoteId = activity.entity.id.trim();

        if (quoteId.isEmpty) return null;

        return () => _navigate(
          context,
          QuoteDetailScreen(quoteId: quoteId, forceStaffWorkspace: true),
        );

      case ActivityEntityType.patient:
      case ActivityEntityType.patientLinkRequest:
        return () => _navigate(
          context,
          const ProfilesScreen(allowExplicitContactLink: true),
        );

      case ActivityEntityType.contact:
        return () => _navigate(context, const NativeContactsScreen());

      case ActivityEntityType.inventoryIssue:
        if (appId.trim().isEmpty) return null;

        return () => _navigate(context, const InventoryIssuesScreen());

      case ActivityEntityType.inventoryDelivery:
        if (appId.trim().isEmpty) return null;

        return () => _navigate(context, const InventoryDeliveriesScreen());

      case ActivityEntityType.unknown:
        return null;
    }
  }

  void _navigate(BuildContext context, Widget destination) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  // ─────────────────────────────────────────────
  // Inventory activity subtitles
  // ─────────────────────────────────────────────

  String? _subtitleForActivity(
    ActivityFeedRecord activity,
    List<InventoryLocation> locations,
  ) {
    if (activity.entity.type != ActivityEntityType.inventoryIssue &&
        activity.entity.type != ActivityEntityType.inventoryDelivery) {
      return null;
    }

    final raw = activity.subtitle?.trim();

    if (!_hasText(raw)) return null;

    var result = raw!;

    // Replace location IDs with their display names.
    // Longer IDs first to avoid partial substitutions.
    final sortedLocations = [...locations]
      ..sort((a, b) => b.id.length.compareTo(a.id.length));

    for (final location in sortedLocations) {
      final id = location.id.trim();
      final name = location.name.trim();

      if (id.isEmpty || name.isEmpty || id == name) {
        continue;
      }

      result = result.replaceAll(id, name);
    }

    return _humanizeIssueType(result);
  }

  String _humanizeIssueType(String value) {
    final parts = value.split('•');

    if (parts.isEmpty) return value;

    final rawType = parts.first.trim();

    final friendlyType = switch (rawType.toLowerCase()) {
      'dispose' => 'Disposal',
      'dispense' => 'Dispense',
      'transfer' => 'Transfer',
      _ => rawType,
    };

    if (parts.length == 1) return friendlyType;

    return [
      friendlyType,
      ...parts.skip(1).map((part) => part.trim()),
    ].join(' • ');
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

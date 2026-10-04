// lib/core/home/activities/shared/staff_latest_activity_panel.dart

import 'package:afyakit/features/inventory/records/deliveries/widgets/screens/delivery_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/activities/feed/activity_feed_adapter.dart';
import 'package:afyakit/core/home/activities/feed/activity_feed_providers.dart';
import 'package:afyakit/core/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/core/home/activities/shared/latest_activity_panel.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/screens/issue_details_screen.dart';

import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
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
    final activityAsync = ref.watch(staffActivityFeedProvider);

    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );

    final dispensariesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.dispensary),
    );

    final stores = storesAsync.valueOrNull ?? const <InventoryLocation>[];

    final dispensaries =
        dispensariesAsync.valueOrNull ?? const <InventoryLocation>[];

    final locations = <InventoryLocation>[...stores, ...dispensaries];

    final List<ActivityEntry> entries = ActivityFeedAdapter.fromFeed(
      activityAsync.valueOrNull ?? const [],
      onTapForActivity: (activity) => _onTapForActivity(context, activity),
      subtitleForActivity: (activity) =>
          _subtitleForActivity(activity, locations),
    )..sort((a, b) => b.date.compareTo(a.date));

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
  // Navigation
  // ─────────────────────────────────────────────

  VoidCallback? _onTapForActivity(
    BuildContext context,
    ActivityFeedRecord activity,
  ) {
    switch (activity.entity.type) {
      case ActivityEntityType.payment:
        final invoice = activity.relatedEntity(ActivityEntityType.invoice);

        final paymentId = activity.entity.id.trim();

        if (!_hasText(paymentId) || invoice == null || !_hasText(invoice.id)) {
          return null;
        }

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PaymentDetailScreen(
              invoiceId: invoice.id,
              paymentId: paymentId,
              currencyCode: activity.currencyCode ?? 'KES',
              customerName: activity.subtitle,
              invoiceNumber: invoice.label,
              canManagePayments: true,
            ),
          ),
        );

      case ActivityEntityType.invoice:
        final invoiceId = activity.entity.id.trim();

        if (!_hasText(invoiceId)) {
          return null;
        }

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InvoiceDetailScreen(
              invoiceId: invoiceId,
              forceStaffWorkspace: true,
            ),
          ),
        );

      case ActivityEntityType.quote:
        final quoteId = activity.entity.id.trim();

        if (!_hasText(quoteId)) {
          return null;
        }

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                QuoteDetailScreen(quoteId: quoteId, forceStaffWorkspace: true),
          ),
        );

      case ActivityEntityType.patient:
      case ActivityEntityType.patientLinkRequest:
        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const ProfilesScreen(allowExplicitContactLink: true),
          ),
        );

      case ActivityEntityType.contact:
        return () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ContactsScreen()));

      case ActivityEntityType.inventoryIssue:
        final issueId = activity.entity.id.trim();

        if (!_hasText(issueId)) {
          return null;
        }

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => IssueDetailsScreen(issueId: issueId),
          ),
        );

      // DeliveryDetailScreen currently requires the complete
      // DeliveryRecord rather than only a delivery ID.
      //
      // Keep this non-clickable until that screen/service has
      // a canonical fetch-by-ID route.
      case ActivityEntityType.inventoryDelivery:
        final deliveryId = activity.entity.id.trim();

        if (!_hasText(deliveryId)) {
          return null;
        }

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DeliveryDetailScreen(deliveryId: deliveryId),
          ),
        );

      case ActivityEntityType.unknown:
        return null;
    }
  }

  // ─────────────────────────────────────────────
  // Human-readable inventory subtitles
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

    if (!_hasText(raw)) {
      return null;
    }

    var result = raw!;

    // Replace known location IDs with their human-readable names.
    //
    // Longest IDs first avoids partial replacement if IDs happen
    // to share prefixes.
    final sortedLocations = List<InventoryLocation>.from(locations)
      ..sort((a, b) => b.id.length.compareTo(a.id.length));

    for (final location in sortedLocations) {
      final id = location.id.trim();
      final name = location.name.trim();

      if (id.isEmpty || name.isEmpty || id == name) {
        continue;
      }

      result = result.replaceAll(id, name);
    }

    result = _humanizeIssueType(result);

    return result;
  }

  String _humanizeIssueType(String value) {
    final parts = value.split('•');

    if (parts.isEmpty) {
      return value;
    }

    final type = parts.first.trim().toLowerCase();

    final friendlyType = switch (type) {
      'dispose' => 'Disposal',
      'dispense' => 'Dispense',
      'transfer' => 'Transfer',
      _ => parts.first.trim(),
    };

    if (parts.length == 1) {
      return friendlyType;
    }

    return <String>[
      friendlyType,
      ...parts.skip(1).map((part) => part.trim()),
    ].join(' • ');
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

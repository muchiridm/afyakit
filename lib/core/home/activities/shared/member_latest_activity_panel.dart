// lib/core/home/activities/shared/member_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/activities/feed/activity_feed_adapter.dart';
import 'package:afyakit/core/home/activities/feed/activity_feed_providers.dart';
import 'package:afyakit/core/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/core/home/activities/shared/latest_activity_panel.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';

import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';

class MemberLatestActivityPanel extends ConsumerWidget {
  const MemberLatestActivityPanel({
    super.key,
    required this.contactId,
    this.accountNumber,
    this.maxItems = 3,
    this.onTitleTap,
    this.title = 'Latest Activity',
    this.emptyText = 'No recent member activity yet.',
  });

  /// Real Zoho/contact ID used by clinical patient-contact links.
  final String? contactId;

  /// Member/account number used by some retail documents.
  final String? accountNumber;

  final int? maxItems;
  final VoidCallback? onTitleTap;
  final String title;
  final String emptyText;

  static const int _fallbackMaxItems = 5;

  String? get _cleanContactId {
    final String? id = contactId?.trim();
    if (id == null || id.isEmpty) return null;

    return id;
  }

  String? get _cleanAccountNumber {
    final String? id = accountNumber?.trim();
    if (id == null || id.isEmpty) return null;

    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? scopedContactId = _cleanContactId;
    final String? scopedAccountNumber = _cleanAccountNumber;

    if (scopedContactId == null && scopedAccountNumber == null) {
      return const LatestActivityPanel(
        title: 'Latest Activity',
        icon: Icons.notifications_none,
        loading: false,
        hasError: false,
        entries: <ActivityEntry>[],
        emptyText: 'No patient profiles linked to your account yet.',
        maxItems: _fallbackMaxItems,
      );
    }

    final activityAsync = ref.watch(
      memberActivityFeedProvider(
        MemberActivityScope(
          contactId: scopedContactId,
          accountNumber: scopedAccountNumber,
          limit: 20,
        ),
      ),
    );

    final entries = ActivityFeedAdapter.fromFeed(
      activityAsync.valueOrNull ?? const [],
      onTapForActivity: (activity) => _onTapForActivity(context, activity),
    )..sort((ActivityEntry a, ActivityEntry b) => b.date.compareTo(a.date));

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
              canManagePayments: false,
            ),
          ),
        );

      case ActivityEntityType.invoice:
        final invoiceId = activity.entity.id.trim();
        if (!_hasText(invoiceId)) return null;

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InvoiceDetailScreen(
              invoiceId: invoiceId,
              forceStaffWorkspace: false,
            ),
          ),
        );

      case ActivityEntityType.quote:
        final quoteId = activity.entity.id.trim();
        if (!_hasText(quoteId)) return null;

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                QuoteDetailScreen(quoteId: quoteId, forceStaffWorkspace: false),
          ),
        );

      case ActivityEntityType.contact:
        return () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ContactsScreen()));

      case ActivityEntityType.patient:
      case ActivityEntityType.patientLinkRequest:
      case ActivityEntityType.inventoryIssue:
      case ActivityEntityType.inventoryDelivery:
      case ActivityEntityType.unknown:
        return null;
    }
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

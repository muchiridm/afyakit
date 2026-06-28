// lib/core/home/activities/feed/activity_feed_adapter.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/core/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/core/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';

typedef ActivityFeedTapBuilder =
    VoidCallback? Function(ActivityFeedRecord activity);

class ActivityFeedAdapter {
  const ActivityFeedAdapter._();

  static List<ActivityEntry> fromFeed(
    List<ActivityFeedRecord> items, {
    ActivityFeedTapBuilder? onTapForActivity,
  }) {
    return items.map((activity) {
      return ActivityEntry(
        date: activity.occurredAt,
        widget: ActivityEventTile(
          icon: _iconForType(activity.type),
          title: activity.title,
          subtitle: _subtitle(activity) ?? _fallbackSubtitle(activity),
          timestamp: activityTimestampLabel(date: activity.occurredAt),
          onTap: onTapForActivity?.call(activity),
        ),
      );
    }).toList();
  }

  static String? _subtitle(ActivityFeedRecord activity) {
    final subtitle = activity.subtitle?.trim();
    if (subtitle != null && subtitle.isNotEmpty) return subtitle;

    final patientName = activity.patientName?.trim();
    if (patientName != null && patientName.isNotEmpty) return patientName;

    final quoteNumber = activity.quoteNumber?.trim();
    if (quoteNumber != null && quoteNumber.isNotEmpty) {
      return 'Quote $quoteNumber';
    }

    final invoiceNumber = activity.invoiceNumber?.trim();
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      return 'Invoice $invoiceNumber';
    }

    final paymentReference = activity.paymentReference?.trim();
    if (paymentReference != null && paymentReference.isNotEmpty) {
      return 'Ref: $paymentReference';
    }

    final status = activity.status?.trim();
    if (status != null && status.isNotEmpty) return status;

    return null;
  }

  static String _fallbackSubtitle(ActivityFeedRecord activity) {
    final contactId = activity.contactId?.trim();
    if (contactId != null && contactId.isNotEmpty) return contactId;

    final accountNumber = activity.accountNumber?.trim();
    if (accountNumber != null && accountNumber.isNotEmpty) {
      return accountNumber;
    }

    return 'Activity recorded';
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'contact_created':
      case 'contact_updated':
      case 'contact_deleted':
        return Icons.person_outline;

      case 'patient_created':
      case 'patient_updated':
      case 'patient_linked':
      case 'patient_delinked':
      case 'patient_deactivated':
      case 'patient_link_request_created':
      case 'patient_link_request_approved':
      case 'patient_link_request_rejected':
      case 'patient_link_request_cancelled':
        return Icons.personal_injury_outlined;

      case 'quote_created':
      case 'quote_updated':
      case 'quote_sent':
      case 'quote_marked_sent':
      case 'quote_converted_to_invoice':
        return Icons.request_quote_outlined;

      case 'invoice_created':
      case 'invoice_updated':
      case 'invoice_sent':
      case 'invoice_marked_sent':
        return Icons.receipt_long_outlined;

      case 'payment_recorded':
      case 'payment_updated':
      case 'payment_deleted':
        return Icons.payments_outlined;

      default:
        return Icons.notifications_none;
    }
  }
}

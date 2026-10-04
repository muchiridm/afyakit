// lib/core/home/activities/feed/activity_feed_adapter.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/core/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/core/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';

import 'package:afyakit/features/inventory/records/issues/extensions/issue_status_x.dart';

typedef ActivityFeedTapBuilder =
    VoidCallback? Function(ActivityFeedRecord activity);

typedef ActivityFeedTitleBuilder =
    String? Function(ActivityFeedRecord activity);

typedef ActivityFeedSubtitleBuilder =
    String? Function(ActivityFeedRecord activity);

class ActivityFeedAdapter {
  const ActivityFeedAdapter._();

  static List<ActivityEntry> fromFeed(
    List<ActivityFeedRecord> items, {
    ActivityFeedTapBuilder? onTapForActivity,
    ActivityFeedTitleBuilder? titleForActivity,
    ActivityFeedSubtitleBuilder? subtitleForActivity,
  }) {
    return items.map((activity) {
      final customTitle = titleForActivity?.call(activity)?.trim();

      final customSubtitle = subtitleForActivity?.call(activity)?.trim();

      final String resolvedTitle = _hasText(customTitle)
          ? customTitle!
          : _title(activity);

      final String resolvedSubtitle = _hasText(customSubtitle)
          ? customSubtitle!
          : _subtitle(activity) ?? _fallbackSubtitle(activity);

      final statusPresentation = _statusPresentation(activity);

      return ActivityEntry(
        date: activity.occurredAt,
        widget: ActivityEventTile(
          icon: _iconForType(activity.type),
          title: resolvedTitle,
          subtitle: resolvedSubtitle,
          timestamp: activityTimestampLabel(date: activity.occurredAt),
          statusLabel: statusPresentation?.label,
          statusColor: statusPresentation?.color,
          onTap: onTapForActivity?.call(activity),
        ),
      );
    }).toList();
  }

  // ─────────────────────────────────────────────
  // Titles
  // ─────────────────────────────────────────────

  static String _title(ActivityFeedRecord activity) {
    switch (activity.type) {
      case 'inventory_issue_created':
        return _issueTitle(
          activity,
          transfer: 'Transfer request created',
          dispose: 'Disposal request created',
          dispense: 'Dispense request created',
          fallback: 'Issue request created',
        );

      case 'inventory_issue_approved':
        return _issueTitle(
          activity,
          transfer: 'Transfer request approved',
          dispose: 'Disposal request approved',
          dispense: 'Dispense request approved',
          fallback: 'Issue request approved',
        );

      case 'inventory_issue_rejected':
        return _issueTitle(
          activity,
          transfer: 'Transfer request rejected',
          dispose: 'Disposal request rejected',
          dispense: 'Dispense request rejected',
          fallback: 'Issue request rejected',
        );

      case 'inventory_issue_cancelled':
        return 'Issue request cancelled';

      case 'inventory_issue_issued':
        return 'Stock issued';

      case 'inventory_issue_received':
        return 'Stock received';

      case 'inventory_issue_disposed':
        return 'Items disposed';

      case 'inventory_issue_partially_disposed':
        return 'Items partially disposed';

      case 'inventory_issue_dispensed':
        return 'Items dispensed';

      case 'inventory_issue_partially_dispensed':
        return 'Items partially dispensed';

      case 'inventory_delivery_recorded':
        return 'Delivery recorded';

      default:
        return activity.title;
    }
  }

  static String _issueTitle(
    ActivityFeedRecord activity, {
    required String transfer,
    required String dispose,
    required String dispense,
    required String fallback,
  }) {
    final haystack = <String>[
      activity.title,
      activity.subtitle ?? '',
      activity.entity.label ?? '',
    ].join(' ').toLowerCase();

    if (haystack.contains('dispose')) {
      return dispose;
    }

    if (haystack.contains('dispense')) {
      return dispense;
    }

    if (haystack.contains('transfer')) {
      return transfer;
    }

    return fallback;
  }

  // ─────────────────────────────────────────────
  // Subtitles
  // ─────────────────────────────────────────────

  static String? _subtitle(ActivityFeedRecord activity) {
    final subtitle = activity.subtitle?.trim();

    if (_hasText(subtitle)) {
      return subtitle;
    }

    final label = activity.entity.label?.trim();

    if (_hasText(label)) {
      switch (activity.entity.type) {
        case ActivityEntityType.quote:
          return 'Quote $label';

        case ActivityEntityType.invoice:
          return 'Invoice $label';

        case ActivityEntityType.payment:
          return 'Ref: $label';

        case ActivityEntityType.patient:
        case ActivityEntityType.contact:
        case ActivityEntityType.patientLinkRequest:
        case ActivityEntityType.inventoryIssue:
        case ActivityEntityType.inventoryDelivery:
        case ActivityEntityType.unknown:
          return label;
      }
    }

    final status = activity.status?.trim();

    if (_hasText(status)) {
      return status;
    }

    return null;
  }

  static String _fallbackSubtitle(ActivityFeedRecord activity) {
    final contactId = activity.contactId?.trim();

    if (_hasText(contactId)) {
      return contactId!;
    }

    final accountNumber = activity.accountNumber?.trim();

    if (_hasText(accountNumber)) {
      return accountNumber!;
    }

    return 'Activity recorded';
  }

  // ─────────────────────────────────────────────
  // Status
  // ─────────────────────────────────────────────

  static _ActivityStatusPresentation? _statusPresentation(
    ActivityFeedRecord activity,
  ) {
    final rawStatus = activity.status?.trim();

    if (!_hasText(rawStatus)) {
      return null;
    }

    // Reuse the issue domain's existing status model so
    // Latest Activity matches IssueDetailsScreen exactly.
    if (activity.entity.type == ActivityEntityType.inventoryIssue) {
      final status = _issueStatusFromName(rawStatus!);

      if (status != null) {
        return _ActivityStatusPresentation(
          label: status.label,
          color: status.color,
        );
      }
    }

    // For non-issue activities we currently avoid inventing
    // a new colour system. They can opt into status presentation
    // later using their own domain status adapters.
    return null;
  }

  static IssueStatus? _issueStatusFromName(String value) {
    final normalized = value.trim().replaceAll('_', '').toLowerCase();

    for (final status in IssueStatus.values) {
      final candidate = status.name.replaceAll('_', '').toLowerCase();

      if (candidate == normalized) {
        return status;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // Icons
  // ─────────────────────────────────────────────

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

      case 'inventory_issue_created':
      case 'inventory_issue_approved':
      case 'inventory_issue_rejected':
      case 'inventory_issue_cancelled':
      case 'inventory_issue_issued':
      case 'inventory_issue_received':
      case 'inventory_issue_disposed':
      case 'inventory_issue_partially_disposed':
      case 'inventory_issue_dispensed':
      case 'inventory_issue_partially_dispensed':
        return Icons.inventory_2_outlined;

      case 'inventory_delivery_recorded':
        return Icons.local_shipping_outlined;

      default:
        return Icons.notifications_none;
    }
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _ActivityStatusPresentation {
  const _ActivityStatusPresentation({required this.label, required this.color});

  final String label;
  final Color color;
}

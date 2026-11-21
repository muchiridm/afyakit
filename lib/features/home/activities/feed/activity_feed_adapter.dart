import 'package:flutter/material.dart';

import 'package:afyakit/features/home/activities/feed/activity_feed_record.dart';
import 'package:afyakit/features/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/features/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/features/home/models/activity_entry.dart';

import 'package:afyakit/features/inventory/records/issues/extensions/issue_status_x.dart';

typedef ActivityFeedTapBuilder =
    VoidCallback? Function(ActivityFeedRecord activity);

typedef ActivityFeedTitleBuilder =
    String? Function(ActivityFeedRecord activity);

typedef ActivityFeedSubtitleBuilder =
    String? Function(ActivityFeedRecord activity);

abstract final class ActivityFeedAdapter {
  const ActivityFeedAdapter._();

  // ─────────────────────────────────────────
  // Feed conversion
  // ─────────────────────────────────────────

  static List<ActivityEntry> fromFeed(
    List<ActivityFeedRecord> items, {
    ActivityFeedTapBuilder? onTapForActivity,
    ActivityFeedTitleBuilder? titleForActivity,
    ActivityFeedSubtitleBuilder? subtitleForActivity,
  }) {
    return List<ActivityEntry>.unmodifiable(
      items.map((activity) {
        final customTitle = titleForActivity?.call(activity)?.trim();

        final customSubtitle = subtitleForActivity?.call(activity)?.trim();

        final title = _hasText(customTitle) ? customTitle! : _title(activity);

        final subtitle = _hasText(customSubtitle)
            ? customSubtitle!
            : _subtitle(activity) ?? 'Activity recorded';

        final status = _statusPresentation(activity);

        return ActivityEntry(
          date: activity.occurredAt,
          widget: ActivityEventTile(
            icon: _iconForType(activity.type),
            title: title,
            subtitle: subtitle,
            timestamp: activityTimestampLabel(date: activity.occurredAt),
            statusLabel: status?.label,
            statusColor: status?.color,
            onTap: onTapForActivity?.call(activity),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────
  // Event titles
  // ─────────────────────────────────────────

  static String _title(ActivityFeedRecord activity) {
    return switch (activity.type.trim().toLowerCase()) {
      // Core Records — current and legacy event names
      'health_profile_created' ||
      'profile_created' ||
      'patient_created' => 'Health profile created',

      'health_profile_updated' ||
      'profile_updated' ||
      'patient_updated' => 'Health profile updated',

      'health_profile_deleted' ||
      'profile_deleted' ||
      'patient_deactivated' => 'Health profile updated',

      'health_profile_linked' ||
      'profile_linked' ||
      'patient_linked' => 'Health profile linked',

      'health_profile_unlinked' ||
      'profile_unlinked' ||
      'patient_delinked' => 'Health profile unlinked',

      'health_profile_link_request_created' ||
      'profile_link_request_created' ||
      'patient_link_request_created' => 'Profile link requested',

      'health_profile_link_request_approved' ||
      'profile_link_request_approved' ||
      'patient_link_request_approved' => 'Profile link approved',

      'health_profile_link_request_rejected' ||
      'profile_link_request_rejected' ||
      'patient_link_request_rejected' => 'Profile link rejected',

      'health_profile_link_request_cancelled' ||
      'profile_link_request_cancelled' ||
      'patient_link_request_cancelled' => 'Profile link request cancelled',

      'health_metric_created' => 'Health metric recorded',
      'health_metric_updated' => 'Health metric updated',
      'health_metric_deleted' => 'Health metric removed',

      // Retail
      'contact_created' => 'Contact created',
      'contact_updated' => 'Contact updated',
      'contact_deleted' => 'Contact deleted',

      // Inventory
      'inventory_issue_created' => _issueTitle(
        activity,
        transfer: 'Transfer request created',
        dispose: 'Disposal request created',
        dispense: 'Dispense request created',
        fallback: 'Issue request created',
      ),

      'inventory_issue_approved' => _issueTitle(
        activity,
        transfer: 'Transfer request approved',
        dispose: 'Disposal request approved',
        dispense: 'Dispense request approved',
        fallback: 'Issue request approved',
      ),

      'inventory_issue_rejected' => _issueTitle(
        activity,
        transfer: 'Transfer request rejected',
        dispose: 'Disposal request rejected',
        dispense: 'Dispense request rejected',
        fallback: 'Issue request rejected',
      ),

      'inventory_issue_cancelled' => 'Issue request cancelled',

      'inventory_issue_issued' => 'Stock issued',

      'inventory_issue_received' => 'Stock received',

      'inventory_issue_disposed' => 'Items disposed',

      'inventory_issue_partially_disposed' => 'Items partially disposed',

      'inventory_issue_dispensed' => 'Items dispensed',

      'inventory_issue_partially_dispensed' => 'Items partially dispensed',

      'inventory_delivery_recorded' => 'Delivery recorded',

      // All other events use their backend-provided titles.
      _ => _hasText(activity.title) ? activity.title.trim() : 'Activity',
    };
  }

  static String _issueTitle(
    ActivityFeedRecord activity, {
    required String transfer,
    required String dispose,
    required String dispense,
    required String fallback,
  }) {
    final description = [
      activity.title,
      activity.subtitle ?? '',
      activity.entity.label ?? '',
    ].join(' ').toLowerCase();

    if (description.contains('dispose') || description.contains('disposal')) {
      return dispose;
    }

    if (description.contains('dispense') ||
        description.contains('dispensing')) {
      return dispense;
    }

    if (description.contains('transfer')) {
      return transfer;
    }

    return fallback;
  }

  // ─────────────────────────────────────────
  // Subtitles
  // ─────────────────────────────────────────

  static String? _subtitle(ActivityFeedRecord activity) {
    final subtitle = activity.subtitle?.trim();

    if (_hasText(subtitle)) {
      return subtitle;
    }

    final label = activity.entity.label?.trim();

    if (_hasText(label)) {
      return switch (activity.entity.type) {
        ActivityEntityType.quote => 'Quote $label',
        ActivityEntityType.invoice => 'Invoice $label',
        ActivityEntityType.payment => 'Ref: $label',
        _ => label,
      };
    }

    final status = activity.status?.trim();

    if (_hasText(status)) {
      return status;
    }

    // Do not expose raw member/contact identifiers
    // merely to populate an activity subtitle.
    return null;
  }

  // ─────────────────────────────────────────
  // Status presentation
  // ─────────────────────────────────────────

  static _ActivityStatusPresentation? _statusPresentation(
    ActivityFeedRecord activity,
  ) {
    final rawStatus = activity.status?.trim();

    if (!_hasText(rawStatus)) {
      return null;
    }

    // Reuse the inventory domain's existing
    // status labels and colours.
    if (activity.entity.type == ActivityEntityType.inventoryIssue) {
      final status = _issueStatusFromName(rawStatus!);

      if (status != null) {
        return _ActivityStatusPresentation(
          label: status.label,
          color: status.color,
        );
      }
    }

    return null;
  }

  static IssueStatus? _issueStatusFromName(String value) {
    final normalized = value
        .trim()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .toLowerCase();

    for (final status in IssueStatus.values) {
      final candidate = status.name
          .replaceAll('_', '')
          .replaceAll('-', '')
          .toLowerCase();

      if (candidate == normalized) {
        return status;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────
  // Event icons
  // ─────────────────────────────────────────

  static IconData _iconForType(String type) {
    final event = type.trim().toLowerCase();

    // Core Records
    if (event.startsWith('health_profile_') ||
        event.startsWith('profile_') ||
        event.startsWith('patient_')) {
      return Icons.folder_shared_outlined;
    }

    if (event.startsWith('health_metric_')) {
      return Icons.monitor_heart_outlined;
    }

    if (event.startsWith('health_document_') ||
        event.startsWith('record_document_')) {
      return Icons.description_outlined;
    }

    // Clinical
    if (event.startsWith('prescription_')) {
      return Icons.medication_outlined;
    }

    if (event.startsWith('clinical_')) {
      return Icons.medical_information_outlined;
    }

    // Insurance
    if (event.startsWith('insurance_')) {
      return Icons.verified_user_outlined;
    }

    // Retail
    if (event.startsWith('contact_')) {
      return Icons.person_outline;
    }

    if (event.startsWith('quote_')) {
      return Icons.request_quote_outlined;
    }

    if (event.startsWith('invoice_')) {
      return Icons.receipt_long_outlined;
    }

    if (event.startsWith('payment_')) {
      return Icons.payments_outlined;
    }

    // Inventory
    if (event.startsWith('inventory_delivery_')) {
      return Icons.local_shipping_outlined;
    }

    if (event.startsWith('inventory_')) {
      return Icons.inventory_2_outlined;
    }

    // Occupational Health
    if (event.startsWith('occupational_')) {
      return Icons.health_and_safety_outlined;
    }

    // Diagnostics
    if (event.startsWith('diagnostic_')) {
      return Icons.biotech_outlined;
    }

    return Icons.notifications_none;
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

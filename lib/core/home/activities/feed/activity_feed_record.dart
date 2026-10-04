// lib/core/home/activities/feed/activity_feed_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityEntityType {
  contact('contact'),
  patient('patient'),
  patientLinkRequest('patient_link_request'),
  quote('quote'),
  invoice('invoice'),
  payment('payment'),
  inventoryIssue('inventory_issue'),
  inventoryDelivery('inventory_delivery'),
  unknown('unknown');

  const ActivityEntityType(this.value);

  final String value;

  static ActivityEntityType fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();

    return ActivityEntityType.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => ActivityEntityType.unknown,
    );
  }
}

class ActivityEntityRef {
  const ActivityEntityRef({required this.type, required this.id, this.label});

  final ActivityEntityType type;
  final String id;
  final String? label;

  factory ActivityEntityRef.fromMap(Map<String, dynamic> json) {
    return ActivityEntityRef(
      type: ActivityEntityType.fromValue(_string(json, 'type')),
      id: _string(json, 'id') ?? '',
      label: _string(json, 'label'),
    );
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is num || value is bool) {
      final trimmed = value.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }
}

class ActivityFeedRecord {
  const ActivityFeedRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.entity,
    required this.occurredAt,
    required this.createdAt,
    this.subtitle,
    this.contactId,
    this.accountNumber,
    this.relatedEntities = const <ActivityEntityRef>[],
    this.actorUid,
    this.actorName,
    this.status,
    this.amount,
    this.currencyCode,
    this.backfilled = false,
  });

  final String id;
  final String type;
  final String title;

  /// Primary resource represented by this activity.
  final ActivityEntityRef entity;

  /// Other resources related to the primary entity.
  final List<ActivityEntityRef> relatedEntities;

  /// Actual business/event date.
  ///
  /// This is the correct timeline date for Latest Activity.
  /// Backfilled records use their historical source date here.
  final DateTime occurredAt;

  /// Activity document write date.
  ///
  /// Useful for diagnostics, but not the primary timeline sort date.
  final DateTime createdAt;

  final String? subtitle;

  /// Visibility / member ownership scope.
  final String? contactId;
  final String? accountNumber;

  final String? actorUid;
  final String? actorName;

  final String? status;
  final num? amount;
  final String? currencyCode;

  final bool backfilled;

  DateTime get sortDate => occurredAt;

  ActivityEntityRef? relatedEntity(ActivityEntityType type) {
    for (final entity in relatedEntities) {
      if (entity.type == type && entity.id.trim().isNotEmpty) {
        return entity;
      }
    }

    return null;
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is num || value is bool) {
      final trimmed = value.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  static DateTime? _maybeDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static DateTime _occurredDate(Map<String, dynamic> json) {
    return _maybeDate(json['occurred_at']) ??
        _maybeDate(json['created_at']) ??
        DateTime.now();
  }

  static DateTime _createdDate(Map<String, dynamic> json) {
    return _maybeDate(json['created_at']) ??
        _maybeDate(json['occurred_at']) ??
        DateTime.now();
  }

  static ActivityEntityRef _entity(Map<String, dynamic> json) {
    final raw = json['entity'];

    if (raw is Map<String, dynamic>) {
      return ActivityEntityRef.fromMap(raw);
    }

    if (raw is Map) {
      return ActivityEntityRef.fromMap(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return const ActivityEntityRef(type: ActivityEntityType.unknown, id: '');
  }

  static List<ActivityEntityRef> _relatedEntities(Map<String, dynamic> json) {
    final raw = json['related_entities'];

    if (raw is! List) return const <ActivityEntityRef>[];

    return raw
        .whereType<Map>()
        .map(
          (item) => ActivityEntityRef.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where(
          (entity) =>
              entity.type != ActivityEntityType.unknown &&
              entity.id.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  factory ActivityFeedRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data();

    return ActivityFeedRecord(
      id: _string(json, 'activity_id') ?? doc.id,
      type: _string(json, 'type') ?? 'unknown',
      title: _string(json, 'title') ?? 'Activity',
      subtitle: _string(json, 'subtitle'),
      contactId: _string(json, 'contact_id'),
      accountNumber: _string(json, 'account_number'),
      entity: _entity(json),
      relatedEntities: _relatedEntities(json),
      actorUid: _string(json, 'actor_uid'),
      actorName: _string(json, 'actor_name'),
      status: _string(json, 'status'),
      amount: json['amount'] is num ? json['amount'] as num : null,
      currencyCode: _string(json, 'currency_code'),
      occurredAt: _occurredDate(json),
      createdAt: _createdDate(json),
      backfilled: json['backfilled'] == true,
    );
  }
}

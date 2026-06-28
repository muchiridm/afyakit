// lib/core/home/activities/feed/activity_feed_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityFeedRecord {
  const ActivityFeedRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.occurredAt,
    required this.createdAt,
    this.subtitle,
    this.contactId,
    this.accountNumber,
    this.patientId,
    this.patientName,
    this.patientLinkRequestId,
    this.quoteId,
    this.quoteNumber,
    this.invoiceId,
    this.invoiceNumber,
    this.paymentId,
    this.paymentReference,
    this.status,
    this.amount,
    this.currencyCode,
  });

  final String id;
  final String type;
  final String title;

  /// Actual business/event date.
  ///
  /// This is the correct timeline date for Latest Activity.
  /// Backfilled records use their historical Zoho/Firestore date here.
  final DateTime occurredAt;

  /// Activity document write date.
  ///
  /// Useful for debugging, but not the primary timeline sort date.
  final DateTime createdAt;

  final String? subtitle;

  final String? contactId;
  final String? accountNumber;

  final String? patientId;
  final String? patientName;
  final String? patientLinkRequestId;

  final String? quoteId;
  final String? quoteNumber;

  final String? invoiceId;
  final String? invoiceNumber;

  final String? paymentId;
  final String? paymentReference;

  final String? status;
  final num? amount;
  final String? currencyCode;

  DateTime get sortDate => occurredAt;

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
      patientId: _string(json, 'patient_id'),
      patientName: _string(json, 'patient_name'),
      patientLinkRequestId: _string(json, 'patient_link_request_id'),
      quoteId: _string(json, 'quote_id'),
      quoteNumber: _string(json, 'quote_number'),
      invoiceId: _string(json, 'invoice_id'),
      invoiceNumber: _string(json, 'invoice_number'),
      paymentId: _string(json, 'payment_id'),
      paymentReference: _string(json, 'payment_reference'),
      status: _string(json, 'status'),
      amount: json['amount'] is num ? json['amount'] as num : null,
      currencyCode: _string(json, 'currency_code'),
      occurredAt: _occurredDate(json),
      createdAt: _createdDate(json),
    );
  }
}

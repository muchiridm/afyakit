// lib/core/hq/tenants/models/tenant_details.dart
import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter/foundation.dart';

@immutable
class TenantDetails {
  final String? tagline;
  final String? website;
  final String? email;
  final String? whatsapp;

  final String currency;
  final String? locale;
  final String? supportNote;

  final String? seoTitle;
  final String? seoDescription;

  /// Tenant-scoped human account numbering format.
  ///
  /// Default: "yymm_seq4" → YYMM + 4-digit sequence (e.g. 26020001).
  ///
  /// Notes:
  /// - Backend is the source of truth for allocation.
  /// - Flutter should only display.
  final String accountFormat;

  final Map<String, String> social;
  final Map<String, String> hours;
  final JsonObj address;
  final JsonObj compliance;
  final JsonObj payments;

  const TenantDetails({
    this.tagline,
    this.website,
    this.email,
    this.whatsapp,
    required this.currency,
    this.locale,
    this.supportNote,
    this.seoTitle,
    this.seoDescription,
    this.accountFormat = 'yymm_seq4',
    required this.social,
    required this.hours,
    required this.address,
    required this.compliance,
    required this.payments,
  });

  static String? _s(Object? v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static Map<String, String> _toStrMap(Object? src) {
    if (src is! Map) return const <String, String>{};
    return {for (final e in src.entries) '${e.key}': '${e.value}'};
  }

  static JsonObj _toJsonMap(Object? v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  /// Pull a nested map if present.
  /// We keep this because some payloads still nest under "details".
  static JsonObj _nestedMap(JsonObj root, String key) {
    final v = root[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  factory TenantDetails.fromMap(JsonObj? m) {
    final x = (m ?? const <String, dynamic>{});

    // Optional nesting used by some payload shapes.
    final details = _nestedMap(x, 'details');

    // Account numbering format (no legacy aliases, no prefix/pad anymore).
    final format =
        _s(x['accountFormat']) ?? _s(details['accountFormat']) ?? 'yymm_seq4';

    // payments/compliance sometimes appear under details (keep this tolerance).
    final paymentsMap = _toJsonMap(x['payments']).isNotEmpty
        ? _toJsonMap(x['payments'])
        : _toJsonMap(details['payments']);

    final complianceMap = _toJsonMap(x['compliance']).isNotEmpty
        ? _toJsonMap(x['compliance'])
        : _toJsonMap(details['compliance']);

    return TenantDetails(
      tagline: _s(x['tagline']) ?? _s(details['tagline']),
      website: _s(x['website']) ?? _s(details['website']),
      email: _s(x['email']) ?? _s(details['email']),
      whatsapp: _s(x['whatsapp']) ?? _s(details['whatsapp']),
      currency: _s(x['currency']) ?? _s(details['currency']) ?? 'KES',
      locale: _s(x['locale']) ?? _s(details['locale']),
      supportNote: _s(x['supportNote']) ?? _s(details['supportNote']),
      seoTitle: _s(x['seoTitle']) ?? _s(details['seoTitle']),
      seoDescription: _s(x['seoDescription']) ?? _s(details['seoDescription']),
      accountFormat: format,
      social: _toStrMap(x['social']).isNotEmpty
          ? _toStrMap(x['social'])
          : _toStrMap(details['social']),
      hours: _toStrMap(x['hours']).isNotEmpty
          ? _toStrMap(x['hours'])
          : _toStrMap(details['hours']),
      address: _toJsonMap(x['address']).isNotEmpty
          ? _toJsonMap(x['address'])
          : _toJsonMap(details['address']),
      compliance: complianceMap,
      payments: paymentsMap,
    );
  }

  // ───── mobile money (explicit) ─────
  String? get mobileMoneyName => _s(payments['mobileMoneyName']);
  String? get mobileMoneyAccount => _s(payments['mobileMoneyAccount']);
  String? get mobileMoneyNumber => _s(payments['mobileMoneyNumber']);

  // ───── registration number (explicit) ─────
  String? get registrationNumber => _s(compliance['registrationNumber']);
}

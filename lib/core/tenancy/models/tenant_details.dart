import 'package:flutter/foundation.dart';

import 'tenant_json.dart';

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

  final Map<String, String> social;
  final Map<String, String> hours;
  final Json address;
  final Json compliance;
  final Json payments;

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
    required this.social,
    required this.hours,
    required this.address,
    required this.compliance,
    required this.payments,
  });

  static String? _s(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static Map<String, String> _toStrMap(dynamic src) {
    if (src is! Map) return const <String, String>{};
    return {for (final e in src.entries) '${e.key}': '${e.value}'};
  }

  static Json _toJsonMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  factory TenantDetails.fromMap(Json? m) {
    final x = (m ?? const <String, dynamic>{});

    return TenantDetails(
      tagline: _s(x['tagline']),
      website: _s(x['website']),
      email: _s(x['email']),
      whatsapp: _s(x['whatsapp']),
      currency: _s(x['currency']) ?? 'KES',
      locale: _s(x['locale']),
      supportNote: _s(x['supportNote']),
      seoTitle: _s(x['seoTitle']),
      seoDescription: _s(x['seoDescription']),
      social: _toStrMap(x['social']),
      hours: _toStrMap(x['hours']),
      address: _toJsonMap(x['address']),
      compliance: _toJsonMap(x['compliance']),
      payments: _toJsonMap(x['payments']),
    );
  }

  // ───── mobile money (explicit) ─────
  String? get mobileMoneyName => _s(payments['mobileMoneyName']);
  String? get mobileMoneyAccount => _s(payments['mobileMoneyAccount']);
  String? get mobileMoneyNumber => _s(payments['mobileMoneyNumber']);

  // ───── registration number (explicit) ─────
  String? get registrationNumber => _s(compliance['registrationNumber']);
}

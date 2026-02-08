// lib/core/tenancy/models/tenant_details.dart

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

  /// ✅ Tenant-scoped human account numbering policy
  /// Example: prefix="DP", pad=6 => DP-000123
  final String accountPrefix;
  final int accountPad;

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
    this.accountPrefix = 'DP',
    this.accountPad = 6,
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

  static int? _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = _s(v);
    if (s == null) return null;
    return int.tryParse(s);
  }

  static Map<String, String> _toStrMap(dynamic src) {
    if (src is! Map) return const <String, String>{};
    return {for (final e in src.entries) '${e.key}': '${e.value}'};
  }

  static Json _toJsonMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  /// Pull a nested map if present (tolerant of legacy shapes)
  static Json _nestedMap(Json root, String key) {
    final v = root[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  factory TenantDetails.fromMap(Json? m) {
    final x = (m ?? const <String, dynamic>{});

    // Some older/alternate payloads may put these under "details"
    final details = _nestedMap(x, 'details');

    final rawPrefix =
        _s(x['accountPrefix']) ??
        _s(details['accountPrefix']) ??
        _s(x['account_prefix']) ?? // ultra-legacy tolerance
        _s(details['account_prefix']);

    final rawPad =
        _i(x['accountPad']) ??
        _i(details['accountPad']) ??
        _i(x['account_pad']) ??
        _i(details['account_pad']);

    final prefix = (rawPrefix ?? 'DP').toUpperCase();
    final pad = rawPad ?? 6;

    final safePad = pad.clamp(3, 10);

    // payments/compliance sometimes also appear under details
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
      accountPrefix: prefix.isEmpty ? 'DP' : prefix,
      accountPad: safePad,
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

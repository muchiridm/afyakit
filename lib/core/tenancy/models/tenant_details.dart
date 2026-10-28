// lib/core/tenancy/models/tenant_details.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/utils/utils.dart';

@immutable
class TenantDetails {
  final String? website;
  final String? email;
  final String? whatsapp;

  final String currency;
  final String? locale;
  final String? supportNote;

  final String accountFormat;

  final Map<String, String> social;
  final Map<String, String> hours;
  final JsonObj address;
  final JsonObj compliance;
  final JsonObj payments;

  const TenantDetails({
    this.website,
    this.email,
    this.whatsapp,
    required this.currency,
    this.locale,
    this.supportNote,
    this.accountFormat = 'yymm_seq4',
    required this.social,
    required this.hours,
    required this.address,
    required this.compliance,
    required this.payments,
  });

  factory TenantDetails.fromMap(JsonObj? map) {
    final root = map ?? const <String, dynamic>{};

    final details = _json(root['details']);

    final payments = _json(root['payments']).isNotEmpty
        ? _json(root['payments'])
        : _json(details['payments']);

    final compliance = _json(root['compliance']).isNotEmpty
        ? _json(root['compliance'])
        : _json(details['compliance']);

    return TenantDetails(
      website: _string(root['website']) ?? _string(details['website']),
      email: _string(root['email']) ?? _string(details['email']),
      whatsapp: _string(root['whatsapp']) ?? _string(details['whatsapp']),
      currency:
          _string(root['currency']) ?? _string(details['currency']) ?? 'KES',
      locale: _string(root['locale']) ?? _string(details['locale']),
      supportNote:
          _string(root['supportNote']) ?? _string(details['supportNote']),
      accountFormat:
          _string(root['accountFormat']) ??
          _string(details['accountFormat']) ??
          'yymm_seq4',
      social: _stringMap(root['social']).isNotEmpty
          ? _stringMap(root['social'])
          : _stringMap(details['social']),
      hours: _stringMap(root['hours']).isNotEmpty
          ? _stringMap(root['hours'])
          : _stringMap(details['hours']),
      address: _json(root['address']).isNotEmpty
          ? _json(root['address'])
          : _json(details['address']),
      compliance: compliance,
      payments: payments,
    );
  }

  String? get mobileMoneyName {
    return _string(payments['mobileMoneyName']);
  }

  String? get mobileMoneyAccount {
    return _string(payments['mobileMoneyAccount']);
  }

  String? get mobileMoneyNumber {
    return _string(payments['mobileMoneyNumber']);
  }

  String? get registrationNumber {
    return _string(compliance['registrationNumber']);
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }

    return {
      for (final entry in value.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }

  static JsonObj _json(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }
}

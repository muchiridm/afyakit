// lib/app/models/app_details.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/utils/utils.dart';

@immutable
class AppDetails {
  // Product / public identity
  final String? tagline;
  final String? website;
  final String? email;
  final String? whatsapp;
  final String? supportNote;

  // Product operations
  final String currency;
  final String? locale;
  final String accountFormat;

  // Public / operational metadata
  final Map<String, String> social;
  final Map<String, String> hours;
  final JsonObj address;
  final JsonObj compliance;
  final JsonObj payments;

  // Web / SEO
  final String? seoTitle;
  final String? seoDescription;

  const AppDetails({
    this.tagline,
    this.website,
    this.email,
    this.whatsapp,
    this.supportNote,
    this.currency = 'KES',
    this.locale,
    this.accountFormat = 'yymm_seq4',
    this.social = const <String, String>{},
    this.hours = const <String, String>{},
    this.address = const <String, dynamic>{},
    this.compliance = const <String, dynamic>{},
    this.payments = const <String, dynamic>{},
    this.seoTitle,
    this.seoDescription,
  });

  factory AppDetails.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    return AppDetails(
      tagline: _string(source['tagline']),
      website: _string(source['website']),
      email: _string(source['email']),
      whatsapp: _string(source['whatsapp']),
      supportNote: _string(source['supportNote']),
      currency: _string(source['currency']) ?? 'KES',
      locale: _string(source['locale']),
      accountFormat: _string(source['accountFormat']) ?? 'yymm_seq4',
      social: _stringMap(source['social']),
      hours: _stringMap(source['hours']),
      address: _json(source['address']),
      compliance: _json(source['compliance']),
      payments: _json(source['payments']),
      seoTitle: _string(source['seoTitle']),
      seoDescription: _string(source['seoDescription']),
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

import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/utils/utils.dart';

@immutable
class AppDetails {
  // ─────────────────────────────────────────────
  // Public identity and contact
  // ─────────────────────────────────────────────

  final String? tagline;
  final String? website;
  final String? email;
  final String? whatsapp;
  final String? supportNote;

  // ─────────────────────────────────────────────
  // Product operations
  // ─────────────────────────────────────────────

  final String currency;
  final String? locale;
  final String accountFormat;

  // ─────────────────────────────────────────────
  // Public and operational metadata
  // ─────────────────────────────────────────────

  final Map<String, String> social;
  final Map<String, String> hours;
  final JsonObj address;
  final JsonObj compliance;
  final JsonObj payments;

  // ─────────────────────────────────────────────
  // Web and SEO
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // Firestore decoding
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // Payment details
  // ─────────────────────────────────────────────

  /// Public payment method label.
  ///
  /// Example: M-Pesa Till
  String? get mobileMoneyName => _string(payments['mobileMoneyName']);

  /// Optional payment account or account reference.
  String? get mobileMoneyAccount => _string(payments['mobileMoneyAccount']);

  /// Till, Paybill or other mobile-money number.
  ///
  /// Always treated as a string.
  String? get mobileMoneyNumber => _string(payments['mobileMoneyNumber']);

  // ─────────────────────────────────────────────
  // Compliance details
  // ─────────────────────────────────────────────

  /// Public professional or business
  /// registration number.
  ///
  /// Example: PPB/D/3483
  String? get registrationNumber => _string(compliance['registrationNumber']);

  // ─────────────────────────────────────────────
  // Firestore encoding
  // ─────────────────────────────────────────────

  /// Serialises known AppDetails fields.
  ///
  /// Preserves additional keys already present
  /// inside payments, compliance and address.
  ///
  /// If the backend replaces the complete
  /// profile object, merge this output against
  /// the existing raw profile first to preserve
  /// any unknown top-level fields.
  JsonObj toMap() {
    return <String, dynamic>{
      'tagline': tagline,
      'website': website,
      'email': email,
      'whatsapp': whatsapp,
      'supportNote': supportNote,
      'currency': currency,
      'locale': locale,
      'accountFormat': accountFormat,
      'social': Map<String, String>.from(social),
      'hours': Map<String, String>.from(hours),
      'address': Map<String, dynamic>.from(address),
      'compliance': Map<String, dynamic>.from(compliance),
      'payments': Map<String, dynamic>.from(payments),
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
    };
  }

  // ─────────────────────────────────────────────
  // Immutable updates
  // ─────────────────────────────────────────────

  AppDetails copyWith({
    String? tagline,
    String? website,
    String? email,
    String? whatsapp,
    String? supportNote,
    String? currency,
    String? locale,
    String? accountFormat,
    Map<String, String>? social,
    Map<String, String>? hours,
    JsonObj? address,
    JsonObj? compliance,
    JsonObj? payments,
    String? seoTitle,
    String? seoDescription,
  }) {
    return AppDetails(
      tagline: tagline ?? this.tagline,
      website: website ?? this.website,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      supportNote: supportNote ?? this.supportNote,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
      accountFormat: accountFormat ?? this.accountFormat,
      social: social ?? this.social,
      hours: hours ?? this.hours,
      address: address ?? this.address,
      compliance: compliance ?? this.compliance,
      payments: payments ?? this.payments,
      seoTitle: seoTitle ?? this.seoTitle,
      seoDescription: seoDescription ?? this.seoDescription,
    );
  }

  /// Updates public business details while
  /// preserving unrelated payment/compliance keys.
  AppDetails withBusinessDetails({
    required String whatsapp,
    required String mobileMoneyName,
    required String mobileMoneyNumber,
    required String registrationNumber,
    String? mobileMoneyAccount,
  }) {
    return copyWith(
      whatsapp: whatsapp.trim(),
      payments: <String, dynamic>{
        ...payments,
        'mobileMoneyName': mobileMoneyName.trim(),
        'mobileMoneyNumber': mobileMoneyNumber.trim(),
        if (mobileMoneyAccount != null)
          'mobileMoneyAccount': mobileMoneyAccount.trim(),
      },
      compliance: <String, dynamic>{
        ...compliance,
        'registrationNumber': registrationNumber.trim(),
      },
    );
  }

  // ─────────────────────────────────────────────
  // Parsing helpers
  // ─────────────────────────────────────────────

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

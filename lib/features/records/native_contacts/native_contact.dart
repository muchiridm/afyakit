/// Canonical Firestore Native Contact.
///
/// Native Contacts are the source of truth for contact identity
/// and are shared across applications within a tenant.
///
/// Person:
///   first_name + last_name
///
/// Organisation:
///   company_name
///
/// displayName is derived, never independently persisted.
///
/// Independent of Zoho Books.
class NativeContact {
  const NativeContact({
    required this.accountNumber,
    required this.entityType,
    required this.contactType,
    required this.status,
    required this.appIds,
    this.firstName,
    this.lastName,
    this.companyName,
    this.legacyDisplayName,
    this.phone,
    this.email,
    this.verifiedPhone,
    this.verifiedEmail,
    this.idNumber,
    this.isInsurancePayer = false,
  });

  /// Canonical identifier, owned by Native Contacts.
  ///
  /// Person: AC-XXXXXX
  /// Organisation: ORG-XXXXXX
  final String accountNumber;

  String get id => accountNumber;

  /// 'person' or 'organization'.
  final String entityType;

  /// 'customer', 'vendor', or 'customer_vendor'.
  final String contactType;

  /// Lifecycle status is authoritative on the API.
  final String status;

  bool get isArchived => status == 'inactive';
  bool get isActive => status == 'active';

  /// Application memberships.
  final List<String> appIds;

  // ─────────────────────────────────────────────
  // Canonical identity fields
  // ─────────────────────────────────────────────

  /// Required for person contacts.
  final String? firstName;
  final String? lastName;

  /// Required for organization contacts.
  final String? companyName;

  /// Read-only migration hint from older API responses, never used to invent
  /// first_name/last_name or as the canonical derived displayName.
  final String? legacyDisplayName;

  /// Derived display name.
  ///
  /// Never stored independently in Firestore.
  ///
  /// Person:
  ///   Shamir Henry Parsaoti
  ///
  /// Organization:
  ///   Occuwell Limited
  String get displayName {
    if (entityType == 'organization') {
      return companyName?.trim() ?? '';
    }

    return [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
  }

  bool get isPerson => entityType == 'person';

  bool get isOrganization => entityType == 'organization';

  // ─────────────────────────────────────────────
  // Contact details
  // ─────────────────────────────────────────────

  final String? phone;
  final String? email;
  final String? idNumber;

  final bool isInsurancePayer;

  // ─────────────────────────────────────────────
  // Read-only verified identity information
  // ─────────────────────────────────────────────

  final String? verifiedPhone;
  final String? verifiedEmail;

  // ─────────────────────────────────────────────
  // Parsing helpers
  // ─────────────────────────────────────────────

  static String? _optional(Object? value) {
    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static String _requiredAccountNumber(Object? raw) {
    final value = raw?.toString().trim().toUpperCase() ?? '';

    if (!RegExp(
      r'^(?:AC|ORG)-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
    ).hasMatch(value)) {
      throw const FormatException(
        'Expected canonical Native Contact account_number',
      );
    }

    return value;
  }

  // ─────────────────────────────────────────────
  // JSON deserialization
  // ─────────────────────────────────────────────

  factory NativeContact.fromJson(Map<String, dynamic> json) {
    final entityType = _optional(json['entity_type']) ?? 'person';

    final accountNumber = _requiredAccountNumber(json['account_number']);

    return NativeContact(
      accountNumber: accountNumber,
      entityType: entityType,
      contactType: _optional(json['contact_type']) ?? 'customer',
      status: _optional(json['status']) ?? 'active',
      appIds: json['app_ids'] is List
          ? (json['app_ids'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const [],

      // Canonical person identity
      firstName: _optional(json['first_name']),
      lastName: _optional(json['last_name']),

      // Canonical organisation identity
      companyName: _optional(json['company_name']),
      legacyDisplayName: _optional(json['display_name']),

      // Contact details
      phone: _optional(json['phone']),
      email: _optional(json['email']),
      idNumber: _optional(json['id_number']),

      // Verified identity
      verifiedPhone: _optional(json['verified_phone']),
      verifiedEmail: _optional(json['verified_email']),

      isInsurancePayer: json['is_insurance_payer'] == true,
    );
  }
}

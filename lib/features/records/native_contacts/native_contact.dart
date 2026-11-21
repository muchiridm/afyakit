/// Canonical Firestore Native Contact.
/// Independent of Zoho Books and shared across tenant applications.
class NativeContact {
  const NativeContact({
    required this.displayName,
    required this.entityType,
    required this.contactType,
    required this.status,
    required this.appIds,
    this.companyName,
    this.phone,
    this.mobile,
    this.email,
    this.verifiedPhone,
    this.verifiedEmail,
    this.idNumber,
    required this.accountNumber,
    this.isInsurancePayer = false,
  });

  String get id => accountNumber;

  /// Lifecycle status is authoritative on the API; this is only a UI hint.
  bool get isArchived => status == 'inactive';
  bool get isActive => status == 'active';

  final String displayName;
  final String entityType;
  final String contactType;
  final String status;
  final List<String> appIds;

  // Canonical contact details.
  final String? companyName;
  final String? phone;
  final String? mobile;
  final String? email;
  final String? idNumber;
  final String accountNumber;
  final bool isInsurancePayer;

  // Read-only verified identity information.
  final String? verifiedPhone;
  final String? verifiedEmail;

  static String? _optional(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _requiredAccountNumber(Object? raw) {
    final value = raw?.toString().trim().toUpperCase() ?? '';
    if (!RegExp(r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(value)) {
      throw const FormatException('Expected canonical Native Contact account_number');
    }
    return value;
  }

  factory NativeContact.fromJson(Map<String, dynamic> json) {
    return NativeContact(
      displayName: (json['display_name'] ?? '').toString(),
      entityType: (json['entity_type'] ?? 'person').toString(),
      contactType: (json['contact_type'] ?? 'customer').toString(),
      status: (json['status'] ?? 'active').toString(),
      appIds: json['app_ids'] is List
          ? (json['app_ids'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const [],
      companyName: _optional(json['company_name']),
      phone: _optional(json['phone']),
      mobile: _optional(json['mobile']),
      email: _optional(json['email']),
      verifiedPhone: _optional(json['verified_phone']),
      verifiedEmail: _optional(json['verified_email']),
      idNumber: _optional(json['id_number']),
      accountNumber: _requiredAccountNumber(json['account_number']),
      isInsurancePayer: json['is_insurance_payer'] == true,
    );
  }
}

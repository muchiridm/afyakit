/// Canonical Firestore contact. Not a Zoho Books contact.
class NativeContact {
  const NativeContact({
    required this.id,
    required this.displayName,
    required this.entityType,
    required this.contactType,
    required this.status,
    required this.appIds,
    this.companyName,
    this.phone,
    this.verifiedPhone,
    this.mobile,
    this.email,
    this.verifiedEmail,
    this.accountNumber,
    this.idNumber,
    this.isInsurancePayer = false,
  });

  final String id;
  final String displayName;
  final String entityType;
  final String contactType;
  final String status;
  final List<String> appIds;
  final String? companyName;

  /// Read-only identity phone confirmed by AuthUser verification.
  final String? verifiedPhone;

  /// Read-only verified login email for the current application.
  ///
  /// Supplied by the Native Contacts API from the canonical
  /// AuthUser.emailsByApp entry for the server-authorised app.
  ///
  /// This is not a tenant-wide email and cannot be edited here.
  final String? verifiedEmail;

  /// General contact details, independently editable where authorised.
  final String? phone;
  final String? mobile;
  final String? email;

  /// Canonical account number, assigned through the account workflow.
  final String? accountNumber;

  final String? idNumber;
  final bool isInsurancePayer;

  factory NativeContact.fromJson(Map<String, dynamic> json) => NativeContact(
    id: (json['contact_id'] ?? '').toString(),
    displayName: (json['display_name'] ?? '').toString(),
    entityType: (json['entity_type'] ?? 'person').toString(),
    contactType: (json['contact_type'] ?? 'customer').toString(),
    status: (json['status'] ?? 'active').toString(),
    appIds: (json['app_ids'] is List)
        ? (json['app_ids'] as List).map((e) => e.toString()).toList()
        : const [],
    companyName: json['company_name']?.toString(),
    phone: json['phone']?.toString(),
    verifiedPhone: json['verified_phone']?.toString(),
    verifiedEmail: json['verified_email']?.toString(),
    mobile: json['mobile']?.toString(),
    email: json['email']?.toString(),
    accountNumber: json['account_number']?.toString(),
    idNumber: json['id_number']?.toString(),
    isInsurancePayer: json['is_insurance_payer'] == true,
  );
}

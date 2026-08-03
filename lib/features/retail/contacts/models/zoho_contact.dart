// lib/features/retail/contacts/models/zoho_contact.dart

import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/utils.dart';

enum ContactPatientRelationship {
  self,
  child,
  spouse,
  parent,
  guardian,
  insurance,
  other;

  static ContactPatientRelationship fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return ContactPatientRelationship.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => ContactPatientRelationship.other,
    );
  }

  String get label {
    switch (this) {
      case ContactPatientRelationship.self:
        return 'Self';
      case ContactPatientRelationship.child:
        return 'Child';
      case ContactPatientRelationship.spouse:
        return 'Spouse';
      case ContactPatientRelationship.parent:
        return 'Parent';
      case ContactPatientRelationship.guardian:
        return 'Guardian';
      case ContactPatientRelationship.insurance:
        return 'Insurance';
      case ContactPatientRelationship.other:
        return 'Other';
    }
  }
}

@immutable
class ContactLinkedPatient {
  const ContactLinkedPatient({
    required this.linkId,
    required this.patientId,
    required this.patientDisplayName,
    required this.relationship,
    required this.isActive,
  });

  final String linkId;
  final String patientId;
  final String patientDisplayName;
  final ContactPatientRelationship relationship;
  final bool isActive;

  bool get isInsuranceLink =>
      relationship == ContactPatientRelationship.insurance;

  factory ContactLinkedPatient.fromJson(Object? raw) {
    if (!isRecord(raw)) {
      throw StateError('linked_patients item must be a JSON object');
    }

    final j = (raw as Map).cast<String, Object?>();

    final linkId = readStringOrNull(j['link_id'] ?? j['linkId']);
    final patientId = readStringOrNull(j['patient_id'] ?? j['patientId']);
    final patientDisplayName = readStringOrNull(
      j['patient_display_name'] ?? j['patientDisplayName'],
    );

    if (linkId == null) {
      throw StateError('linked_patients.link_id is required');
    }

    if (patientId == null) {
      throw StateError('linked_patients.patient_id is required');
    }

    if (patientDisplayName == null) {
      throw StateError('linked_patients.patient_display_name is required');
    }

    return ContactLinkedPatient(
      linkId: linkId,
      patientId: patientId,
      patientDisplayName: patientDisplayName,
      relationship: ContactPatientRelationship.fromJson(j['relationship']),
      isActive: readBool(j['is_active'] ?? j['isActive']) ?? true,
    );
  }

  ContactLinkedPatient copyWith({
    String? linkId,
    String? patientId,
    String? patientDisplayName,
    ContactPatientRelationship? relationship,
    bool? isActive,
  }) {
    return ContactLinkedPatient(
      linkId: linkId ?? this.linkId,
      patientId: patientId ?? this.patientId,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class PersonContact {
  const PersonContact({
    required this.personName,
    this.contactPersonId,
    this.email,
    this.phone,
    this.mobile,
    this.isPrimary,
  });

  final String personName;
  final String? contactPersonId;
  final String? email;
  final String? phone;
  final String? mobile;
  final bool? isPrimary;

  factory PersonContact.fromJson(Object? raw) {
    if (!isRecord(raw)) {
      throw StateError('person_contact must be a JSON object');
    }

    final j = (raw as Map).cast<String, Object?>();

    final name = readStringOrNull(j['person_name']);
    if (name == null) {
      throw StateError('person_contact.person_name is required');
    }

    return PersonContact(
      personName: name,
      contactPersonId: readStringOrNull(j['contact_person_id']),
      email: readStringOrNull(j['email']),
      phone: readStringOrNull(j['phone']),
      mobile: readStringOrNull(j['mobile']),
      isPrimary: readBool(j['is_primary']),
    );
  }

  /// Payload format your backend expects when creating/updating contacts.
  Map<String, Object?> toJsonForUpsert() {
    final name = personName.trim();
    if (name.isEmpty) {
      throw StateError('personName cannot be empty');
    }

    return <String, Object?>{
      'person_name': name,
      if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
      if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
      if ((mobile ?? '').trim().isNotEmpty) 'mobile': mobile!.trim(),
    };
  }
}

@immutable
class ZohoContact {
  const ZohoContact({
    required this.contactId,
    required this.displayName,
    this.companyName,
    this.personContact,
    this.status,
    this.contactType,
    this.accountNumber,
    this.phone,
    this.mobile,
    this.email,
    this.createdTime,
    this.lastModifiedTime,
    this.isInsurancePayer = false,
    this.linkedPatients = const <ContactLinkedPatient>[],
  });

  final String contactId;
  final String displayName;
  final String? companyName;
  final PersonContact? personContact;
  final String? status;

  /// "customer" | "vendor" | "customer_vendor" | null
  final String? contactType;

  /// Deterministic linking key from Zoho Books custom field cf_account_number.
  /// Wire name from BE: account_number
  final String? accountNumber;

  /// Contact-level phone fields from backend/Zoho.
  ///
  /// These are important for company-only contacts where personContact is null.
  final String? phone;
  final String? mobile;
  final String? email;

  /// Zoho timestamps passed through by the backend.
  ///
  /// Wire names:
  /// - created_time
  /// - last_modified_time
  final DateTime? createdTime;
  final DateTime? lastModifiedTime;

  /// Contact-level flag from Zoho Books custom field cf_is_insurance_payer.
  /// Wire name from BE: is_insurance_payer
  final bool isInsurancePayer;

  /// Clinical patients linked to this contact/payer.
  ///
  /// Wire name from BE: linked_patients
  /// Source of truth is Firestore clinical_contact_patients, not Zoho.
  final List<ContactLinkedPatient> linkedPatients;

  bool get isActive => (status ?? '').toLowerCase() != 'inactive';

  /// Used by activity panels.
  ///
  /// Prefer last modification time, fallback to creation time, then epoch so
  /// older/incomplete records sort below real timestamped records.
  DateTime get activityDate {
    return lastModifiedTime ??
        createdTime ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get isCompanyOnly {
    final company = (companyName ?? '').trim().toLowerCase();
    if (company.isEmpty) return false;

    final person = personContact?.personName.trim();
    if (person != null && person.isNotEmpty) return false;

    final display = displayName.trim().toLowerCase();

    // True company-only contact:
    // SRH / South Rift Hospital where contact_name == company_name.
    if (display.isNotEmpty && display == company) return true;

    // If display is just the generic fallback, company is the real identity.
    if (display.isEmpty || display == 'contact') return true;

    // Otherwise this is probably a person/contact attached to a company.
    return false;
  }

  bool get hasLinkedPatients => linkedPatients.isNotEmpty;

  List<ContactLinkedPatient> get activeLinkedPatients {
    return linkedPatients.where((p) => p.isActive).toList(growable: false);
  }

  List<ContactLinkedPatient> get activeInsuranceLinkedPatients {
    return activeLinkedPatients
        .where((p) => p.relationship == ContactPatientRelationship.insurance)
        .toList(growable: false);
  }

  int get activeLinkedPatientCount => activeLinkedPatients.length;

  int get activeInsuranceLinkedPatientCount =>
      activeInsuranceLinkedPatients.length;

  String get linkedPatientsSummary {
    final active = activeLinkedPatients;
    if (active.isEmpty) return '';

    if (active.length == 1) {
      return active.first.patientDisplayName;
    }

    return '${active.length} linked patients';
  }

  String get bestPhone {
    final contactMobile = mobile?.trim();
    if (contactMobile != null && contactMobile.isNotEmpty) {
      return contactMobile;
    }

    final personMobile = personContact?.mobile?.trim();
    if (personMobile != null && personMobile.isNotEmpty) {
      return personMobile;
    }

    final contactPhone = phone?.trim();
    if (contactPhone != null && contactPhone.isNotEmpty) {
      return contactPhone;
    }

    final personPhone = personContact?.phone?.trim();
    if (personPhone != null && personPhone.isNotEmpty) {
      return personPhone;
    }

    return '';
  }

  String get bestEmail {
    final contactEmail = email?.trim();
    if (contactEmail != null && contactEmail.isNotEmpty) {
      return contactEmail;
    }

    final personEmail = personContact?.email?.trim();
    if (personEmail != null && personEmail.isNotEmpty) {
      return personEmail;
    }

    return '';
  }

  String get contactTypeNorm => (contactType ?? '').trim().toLowerCase();

  bool get isCustomer {
    final t = contactTypeNorm;
    return t == 'customer' || t == 'customer_vendor';
  }

  bool get isVendor {
    final t = contactTypeNorm;
    return t == 'vendor' || t == 'customer_vendor';
  }

  /// Primary label for tiles/search pickers.
  ///
  /// Company-only contacts must still show. Do not depend on personContact.
  String get displayLabel {
    final display = displayName.trim();

    if (display.isNotEmpty && display.toLowerCase() != 'contact') {
      return display;
    }

    final person = personContact?.personName.trim();
    if (person != null && person.isNotEmpty) return person;

    final company = companyName?.trim();
    if (company != null && company.isNotEmpty) return company;

    final id = contactId.trim();
    if (id.isNotEmpty) return id;

    return 'Contact';
  }

  String get title => displayLabel;

  String get subtitle {
    final parts = <String>[];

    final company = companyName?.trim();
    if (company != null &&
        company.isNotEmpty &&
        company.toLowerCase() != displayLabel.toLowerCase()) {
      parts.add(company);
    }

    final person = personContact?.personName.trim();
    if (person != null &&
        person.isNotEmpty &&
        person.toLowerCase() != displayLabel.toLowerCase()) {
      parts.add(person);
    }

    final linked = linkedPatientsSummary.trim();
    if (linked.isNotEmpty) parts.add(linked);

    final p = bestPhone.trim();
    if (p.isNotEmpty) parts.add(p);

    final e = bestEmail.trim();
    if (e.isNotEmpty) parts.add(e);

    if (isInsurancePayer) {
      parts.add('Insurance payer');
    } else if (isCompanyOnly) {
      parts.add('Company');
    }

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) parts.add(acct);

    if (parts.isNotEmpty) return parts.join(' • ');

    final type = contactTypeNorm;
    if (type.isNotEmpty) return type;

    return '';
  }

  // ─────────────────────────────────────────────
  // JSON
  // ─────────────────────────────────────────────

  factory ZohoContact.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    final id = readString(j['contact_id'] ?? j['contactId'] ?? j['id']);

    final display = readStringOrNull(j['display_name'] ?? j['displayName']);
    final company = readStringOrNull(j['company_name'] ?? j['companyName']);
    final status = readStringOrNull(j['status']);

    final contactType = readStringOrNull(j['contact_type'] ?? j['contactType']);

    final accountNumberRaw = readStringOrNull(
      j['account_number'] ?? j['accountNumber'],
    );

    final phone = readStringOrNull(j['phone']);
    final mobile = readStringOrNull(j['mobile']);
    final email = readStringOrNull(j['email']);

    final createdTime = _readDateTime(
      j['created_time'] ??
          j['createdTime'] ??
          j['created_at'] ??
          j['createdAt'],
    );

    final lastModifiedTime = _readDateTime(
      j['last_modified_time'] ??
          j['lastModifiedTime'] ??
          j['updated_time'] ??
          j['updatedTime'] ??
          j['updated_at'] ??
          j['updatedAt'],
    );

    final isInsurancePayer =
        readBool(j['is_insurance_payer'] ?? j['isInsurancePayer']) ?? false;

    PersonContact? person;

    // Backend shape: person_contact is nested
    if (j.containsKey('person_contact')) {
      final rawPc = j['person_contact'];
      person = rawPc == null ? null : PersonContact.fromJson(rawPc);
    } else {
      // Zoho native legacy shape: contact_persons array
      person = _pickPrimaryFromZohoLegacy(j);
    }

    final zohoContactName = readStringOrNull(
      j['contact_name'] ?? j['contactName'],
    );

    final derived = _deriveDisplayName(
      display: display ?? zohoContactName,
      company: company,
      person: person?.personName,
    );

    final acct = (accountNumberRaw ?? '').trim();

    return ZohoContact(
      contactId: id,
      displayName: derived,
      companyName: company,
      personContact: person,
      status: status,
      contactType: contactType,
      accountNumber: acct.isNotEmpty ? acct : null,
      phone: _cleanOrNull(phone),
      mobile: _cleanOrNull(mobile),
      email: _cleanOrNull(email),
      createdTime: createdTime,
      lastModifiedTime: lastModifiedTime,
      isInsurancePayer: isInsurancePayer,
      linkedPatients: _readLinkedPatients(j),
    );
  }

  static String? _cleanOrNull(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static DateTime? _readDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    // Zoho may return: 2026-06-25 15:25:49
    final normalized = raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);

    return parsed;
  }

  static List<ContactLinkedPatient> _readLinkedPatients(
    Map<String, Object?> j,
  ) {
    final raw = j['linked_patients'] ?? j['linkedPatients'];

    if (raw is! List) return const <ContactLinkedPatient>[];

    return raw
        .whereType<Map>()
        .map((item) => ContactLinkedPatient.fromJson(item))
        .toList(growable: false);
  }

  static String _deriveDisplayName({
    required String? display,
    required String? company,
    required String? person,
  }) {
    final d = (display ?? '').trim();
    if (d.isNotEmpty) return d;

    final c = (company ?? '').trim();
    if (c.isNotEmpty) return c;

    final p = (person ?? '').trim();
    if (p.isNotEmpty) return p;

    return 'Contact';
  }

  static PersonContact? _pickPrimaryFromZohoLegacy(Map<String, Object?> j) {
    final raw = j['contact_persons'];
    if (raw is! List) return null;
    if (raw.isEmpty) return null;

    Map<String, Object?>? primary;

    for (final item in raw) {
      if (!isRecord(item)) continue;
      final m = (item as Map).cast<String, Object?>();

      final isPrimary = readBool(m['is_primary_contact']);
      if (isPrimary == true) {
        primary = m;
        break;
      }
    }

    primary ??= isRecord(raw.first)
        ? (raw.first as Map).cast<String, Object?>()
        : null;

    if (primary == null) return null;

    final first = readStringOrNull(primary['first_name']);
    final last = readStringOrNull(primary['last_name']);

    final full = <String>[
      if (first != null) first.trim(),
      if (last != null) last.trim(),
    ].where((s) => s.isNotEmpty).join(' ').trim();

    if (full.isEmpty) return null;

    return PersonContact(
      personName: full,
      contactPersonId: readStringOrNull(primary['contact_person_id']),
      email: readStringOrNull(primary['email']) ?? readStringOrNull(j['email']),
      phone: readStringOrNull(primary['phone']) ?? readStringOrNull(j['phone']),
      mobile:
          readStringOrNull(primary['mobile']) ?? readStringOrNull(j['mobile']),
      isPrimary: true,
    );
  }

  Map<String, Object?> toCreateJson() {
    final dn = displayName.trim();
    if (dn.isEmpty) {
      throw StateError('displayName is required');
    }

    final company = (companyName ?? '').trim();
    final acct = (accountNumber ?? '').trim();

    return <String, Object?>{
      'display_name': dn,
      if (company.isNotEmpty) 'company_name': company,
      if (acct.isNotEmpty) 'account_number': acct,
      if (isInsurancePayer) 'is_insurance_payer': true,
      if (personContact != null)
        'person_contact': personContact!.toJsonForUpsert(),
    };
  }

  ZohoContact copyWith({
    String? contactId,
    String? displayName,
    String? companyName,
    PersonContact? personContact,
    String? status,
    String? contactType,
    String? accountNumber,
    String? phone,
    String? mobile,
    String? email,
    DateTime? createdTime,
    DateTime? lastModifiedTime,
    bool? isInsurancePayer,
    List<ContactLinkedPatient>? linkedPatients,
  }) {
    return ZohoContact(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      personContact: personContact ?? this.personContact,
      status: status ?? this.status,
      contactType: contactType ?? this.contactType,
      accountNumber: accountNumber ?? this.accountNumber,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      createdTime: createdTime ?? this.createdTime,
      lastModifiedTime: lastModifiedTime ?? this.lastModifiedTime,
      isInsurancePayer: isInsurancePayer ?? this.isInsurancePayer,
      linkedPatients: linkedPatients ?? this.linkedPatients,
    );
  }
}

@immutable
class ContactUpdatePatch {
  const ContactUpdatePatch({
    this.displayName,
    this.companyName,
    this.personContact,
    this.accountNumber,
    this.isInsurancePayer,
  });

  final String? displayName;
  final String? companyName;
  final PersonContactPatch? personContact;

  /// BE expects: account_number, which writes to Zoho cf_account_number.
  final String? accountNumber;

  /// BE expects: is_insurance_payer, which writes to Zoho cf_is_insurance_payer.
  final bool? isInsurancePayer;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};

    if (displayName != null) {
      final dn = displayName!.trim();
      if (dn.isEmpty) throw StateError('displayName cannot be empty');
      out['display_name'] = dn;
    }

    if (companyName != null) {
      out['company_name'] = companyName!.trim().isEmpty
          ? ''
          : companyName!.trim();
    }

    if (accountNumber != null) {
      final acct = accountNumber!.trim();
      // empty string => explicit clear
      out['account_number'] = acct.isEmpty ? '' : acct;
    }

    if (isInsurancePayer != null) {
      out['is_insurance_payer'] = isInsurancePayer;
    }

    if (personContact != null) {
      // If patch returns null, caller should set person_contact: null.
      out['person_contact'] = personContact!.toJson();
    }

    return out;
  }
}

@immutable
class PersonContactPatch {
  const PersonContactPatch({
    this.personName,
    this.email,
    this.phone,
    this.mobile,
    this.delete,
  });

  final bool? delete;

  final String? personName;
  final String? email;
  final String? phone;
  final String? mobile;

  Map<String, Object?>? toJson() {
    if (delete == true) return null;

    final out = <String, Object?>{};

    if (personName != null) {
      out['person_name'] = personName!.trim().isEmpty ? '' : personName!.trim();
    }

    if (email != null) {
      out['email'] = email!.trim().isEmpty ? '' : email!.trim();
    }

    if (phone != null) {
      out['phone'] = phone!.trim().isEmpty ? '' : phone!.trim();
    }

    if (mobile != null) {
      out['mobile'] = mobile!.trim().isEmpty ? '' : mobile!.trim();
    }

    return out;
  }
}

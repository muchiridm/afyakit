// lib/features/retail/shared/models/zoho_contact.dart

import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/utils.dart';

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
    required this.displayName, // only required field in FE
    this.companyName,
    this.personContact,
    this.status,
    this.contactType,
    this.accountNumber,
  });

  final String contactId;
  final String displayName;
  final String? companyName;
  final PersonContact? personContact;
  final String? status;

  /// "customer" | "vendor" | "customer_vendor" | null
  final String? contactType;

  /// ✅ Deterministic linking key (Zoho Books custom field cf_account_number).
  /// Wire name (BE API): account_number
  final String? accountNumber;

  bool get isActive => (status ?? '').toLowerCase() != 'inactive';

  String get bestPhone {
    final m = personContact?.mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    final p = personContact?.phone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return '';
  }

  String get bestEmail {
    final e = personContact?.email?.trim();
    if (e != null && e.isNotEmpty) return e;
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

  String get title {
    final d = displayName.trim();
    if (d.isNotEmpty) return d;

    final p = personContact?.personName.trim();
    if (p != null && p.isNotEmpty) return p;

    final c = companyName?.trim();
    if (c != null && c.isNotEmpty) return c;

    return '';
  }

  /// ✅ Prefer showing account number (linking key), then type, then phone/email.
  String get subtitle {
    final acct = (accountNumber ?? '').trim();
    final type = contactTypeNorm;

    if (acct.isNotEmpty && type.isNotEmpty) return '$acct • $type';
    if (acct.isNotEmpty) return acct;
    if (type.isNotEmpty) return type;

    final p = bestPhone.trim();
    if (p.isNotEmpty) return p;

    final e = bestEmail.trim();
    if (e.isNotEmpty) return e;

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

    // ✅ New world: account_number only (BE emits this from cf_account_number)
    //
    // Keep a permissive fallback for camelCase, but DO NOT support reference_number.
    final accountNumberRaw = readStringOrNull(
      j['account_number'] ?? j['accountNumber'],
    );

    PersonContact? person;

    // Backend shape: person_contact is nested
    if (j.containsKey('person_contact')) {
      final rawPc = j['person_contact'];
      person = rawPc == null ? null : PersonContact.fromJson(rawPc);
    } else {
      // Zoho native legacy shape: contact_persons array
      // (This is not "our legacy"; it's Zoho's payload reality)
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
    );
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

      // ✅ include only if present
      if (acct.isNotEmpty) 'account_number': acct,

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
  }) {
    return ZohoContact(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      personContact: personContact ?? this.personContact,
      status: status ?? this.status,
      contactType: contactType ?? this.contactType,
      accountNumber: accountNumber ?? this.accountNumber,
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
  });

  final String? displayName;
  final String? companyName;
  final PersonContactPatch? personContact;

  /// ✅ BE expects: account_number (custom field cf_account_number)
  final String? accountNumber;

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

    if (personContact != null) {
      // IMPORTANT: if patch returns null, caller should set person_contact: null
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

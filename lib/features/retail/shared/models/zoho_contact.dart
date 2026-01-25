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
    this.contactType, // NEW
  });

  final String contactId;
  final String displayName;
  final String? companyName;
  final PersonContact? personContact;
  final String? status;

  /// "customer" | "vendor" | "customer_vendor" | null
  final String? contactType;

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

  String get subtitle {
    final p = bestPhone.trim();
    if (p.isNotEmpty) return p;
    final e = bestEmail.trim();
    if (e.isNotEmpty) return e;
    return '';
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

  String get contactTypeNorm => (contactType ?? '').trim().toLowerCase();

  bool get isCustomer {
    final t = contactTypeNorm;
    return t == 'customer' || t == 'customer_vendor';
  }

  bool get isVendor {
    final t = contactTypeNorm;
    return t == 'vendor' || t == 'customer_vendor';
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

    final contactType = readStringOrNull(
      j['contact_type'] ?? j['type'] ?? j['contactType'],
    );

    PersonContact? person;

    // New backend shape: person_contact is nested
    if (j.containsKey('person_contact')) {
      final rawPc = j['person_contact'];
      person = rawPc == null ? null : PersonContact.fromJson(rawPc);
    } else {
      // Legacy flat shape: person_name + phone/email/mobile
      final legacyPersonName = readStringOrNull(j['person_name']);
      if (legacyPersonName != null) {
        person = PersonContact(
          personName: legacyPersonName,
          contactPersonId: readStringOrNull(j['contact_person_id']),
          email: readStringOrNull(j['email']),
          phone: readStringOrNull(j['phone']),
          mobile: readStringOrNull(j['mobile']),
          isPrimary: readBool(j['is_primary']),
        );
      } else {
        // Zoho native legacy shape: contact_persons array
        person = _pickPrimaryFromZohoLegacy(j);
      }
    }

    final zohoContactName = readStringOrNull(
      j['contact_name'] ?? j['contactName'],
    );

    final derived = _deriveDisplayName(
      display: display ?? zohoContactName,
      company: company,
      person: person?.personName,
    );

    return ZohoContact(
      contactId: id,
      displayName: derived,
      companyName: company,
      personContact: person,
      status: status,
      contactType: contactType,
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

    return <String, Object?>{
      'display_name': dn,
      if (company.isNotEmpty) 'company_name': company,
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
  }) {
    return ZohoContact(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      personContact: personContact ?? this.personContact,
      status: status ?? this.status,
      contactType: contactType ?? this.contactType,
    );
  }
}

@immutable
class ContactUpdatePatch {
  const ContactUpdatePatch({
    this.displayName,
    this.companyName,
    this.personContact,
  });

  final String? displayName;
  final String? companyName;
  final PersonContactPatch? personContact;

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

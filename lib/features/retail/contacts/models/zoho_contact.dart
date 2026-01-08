// lib/features/retail/contacts/models/zoho_contact.dart

class PersonContact {
  const PersonContact({
    required this.personName,
    this.contactPersonId,
    this.email,
    this.phone,
    this.mobile,
    this.isPrimary,
  });

  final String personName; // required when object exists
  final String? contactPersonId;
  final String? email;
  final String? phone;
  final String? mobile;
  final bool? isPrimary;

  static String? _s(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static Map<String, Object?>? _m(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    return null;
  }

  factory PersonContact.fromJson(Object? raw) {
    final j = _m(raw);
    if (j == null) {
      throw StateError('person_contact must be a JSON object');
    }

    final name = _s(j['person_name']) ?? '';
    if (name.isEmpty) {
      throw StateError('person_contact.person_name is required');
    }

    return PersonContact(
      personName: name,
      contactPersonId: _s(j['contact_person_id']),
      email: _s(j['email']),
      phone: _s(j['phone']),
      mobile: _s(j['mobile']),
      isPrimary: j['is_primary'] is bool ? j['is_primary'] as bool : null,
    );
  }

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

class ZohoContact {
  const ZohoContact({
    required this.contactId,
    required this.displayName, // ✅ only required field in FE
    this.companyName,
    this.personContact,
    this.status,
  });

  final String contactId;
  final String displayName;
  final String? companyName;
  final PersonContact? personContact;
  final String? status;

  bool get isActive => (status ?? '').toLowerCase() != 'inactive';

  String get bestPhone {
    final m = personContact?.mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    final p = personContact?.phone?.trim();
    if (p != null && p.isNotEmpty) return p;
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

  // ─────────────────────────────────────────────
  // JSON helpers (strict, no any)
  // ─────────────────────────────────────────────

  static String? _s(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static Map<String, Object?>? _m(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    return null;
  }

  static List<Object?>? _l(Object? v) {
    if (v is List) return v.cast<Object?>();
    return null;
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

  // Legacy Zoho fallback: contact_persons array
  static PersonContact? _pickPrimaryFromZohoLegacy(Map<String, Object?> j) {
    final cpsRaw = _l(j['contact_persons']);
    if (cpsRaw == null || cpsRaw.isEmpty) return null;

    Map<String, Object?>? primary;
    for (final item in cpsRaw) {
      final m = _m(item);
      if (m == null) continue;
      final isPrimary = m['is_primary_contact'];
      if (isPrimary is bool && isPrimary == true) {
        primary = m;
        break;
      }
    }
    primary ??= _m(cpsRaw.first);
    if (primary == null) return null;

    final first = _s(primary['first_name']);
    final last = _s(primary['last_name']);
    final full = [
      first ?? '',
      last ?? '',
    ].where((s) => s.trim().isNotEmpty).join(' ').trim();
    final personName = full.isEmpty ? null : full;

    if (personName == null) return null;

    return PersonContact(
      personName: personName,
      contactPersonId: _s(primary['contact_person_id']),
      email: _s(primary['email']) ?? _s(j['email']),
      phone: _s(primary['phone']) ?? _s(j['phone']),
      mobile: _s(primary['mobile']) ?? _s(j['mobile']),
      isPrimary: true,
    );
  }

  factory ZohoContact.fromJson(Map<String, dynamic> json) {
    final j = json.cast<String, Object?>();

    // New API (preferred)
    final id = _s(j['contact_id']) ?? '';
    final display = _s(j['display_name']); // ✅ new
    final company = _s(j['company_name']);
    final status = _s(j['status']);

    PersonContact? person;
    if (j.containsKey('person_contact')) {
      final rawPc = j['person_contact'];
      if (rawPc == null) {
        person = null;
      } else {
        person = PersonContact.fromJson(rawPc);
      }
    } else {
      // Legacy fallbacks while migrating
      final legacyPersonName = _s(j['person_name']);
      if (legacyPersonName != null) {
        person = PersonContact(
          personName: legacyPersonName,
          email: _s(j['email']),
          phone: _s(j['phone']),
          mobile: _s(j['mobile']),
        );
      } else {
        person = _pickPrimaryFromZohoLegacy(j);
      }
    }

    // Also accept Zoho's contact_name during transition
    final zohoContactName = _s(j['contact_name']);
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
    );
  }

  /// Create payload for NEW backend contract.
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
  }) {
    return ZohoContact(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      personContact: personContact ?? this.personContact,
      status: status ?? this.status,
    );
  }
}

/// Patch object for updates that supports:
/// - omitted field => do not touch
/// - value => set/update
/// - null => clear/delete
class ContactUpdatePatch {
  const ContactUpdatePatch({
    this.displayName,
    this.companyName,
    this.personContact,
  });

  /// If provided, must not be empty.
  final String? displayName;

  /// null => clear company name
  /// string => set company name
  final String? companyName;

  /// null => delete person contact
  /// object => upsert person contact
  final PersonContactPatch? personContact;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{};

    if (displayName != null) {
      final dn = displayName!.trim();
      if (dn.isEmpty) {
        throw StateError('displayName cannot be empty');
      }
      out['display_name'] = dn;
    }

    if (companyName != null) {
      // Treat empty as clear
      final cn = companyName!.trim();
      out['company_name'] = cn.isEmpty ? '' : cn;
    }

    if (personContact != null) {
      out['person_contact'] = personContact!.toJson();
    }

    return out;
  }
}

class PersonContactPatch {
  const PersonContactPatch({
    this.personName,
    this.email,
    this.phone,
    this.mobile,
    this.delete,
  });

  /// If delete==true, backend should delete primary person contact.
  final bool? delete;

  final String? personName;
  final String? email;
  final String? phone;
  final String? mobile;

  Map<String, Object?>? toJson() {
    if (delete == true) {
      return null; // IMPORTANT: caller sets person_contact: null
    }

    final out = <String, Object?>{};

    if (personName != null) {
      final pn = personName!.trim();
      out['person_name'] = pn.isEmpty ? '' : pn;
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

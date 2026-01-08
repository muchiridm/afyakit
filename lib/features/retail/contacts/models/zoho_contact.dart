// lib/features/contacts/models/zoho_contact.dart

class ZohoContact {
  const ZohoContact({
    required this.contactId,
    required this.displayName, // ✅ only required field in FE
    this.personName, // optional
    this.companyName, // optional
    this.email,
    this.phone,
    this.mobile,
    this.status,
  });

  final String contactId;

  /// FE-required label (maps to Zoho `contact_name`)
  final String displayName;

  /// Optional: person name (stored in Zoho as primary contact_person)
  final String? personName;

  /// Optional: company / organization name (Zoho `company_name`)
  final String? companyName;

  /// These map to the PRIMARY contact person in Zoho (when we send contact_persons).
  /// If Zoho returns top-level email/phone/mobile, we still accept them.
  final String? email;
  final String? phone;
  final String? mobile;

  /// Zoho typically uses "active" / "inactive"
  final String? status;

  bool get isActive => (status ?? '').toLowerCase() != 'inactive';

  String get bestPhone {
    final m = mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    final p = phone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return '';
  }

  /// What to show on UI tiles (prefer displayName, fallback)
  String get title {
    final d = displayName.trim();
    if (d.isNotEmpty) return d;
    final p = personName?.trim();
    if (p != null && p.isNotEmpty) return p;
    final c = companyName?.trim();
    if (c != null && c.isNotEmpty) return c;
    return '';
  }

  // ─────────────────────────────────────────────
  // JSON helpers (no `any`)
  // ─────────────────────────────────────────────

  static String? _readString(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static Map<String, Object?>? _readMap(Object? v) {
    if (v is Map) {
      return v.cast<String, Object?>();
    }
    return null;
  }

  static List<Object?>? _readList(Object? v) {
    if (v is List) return v.cast<Object?>();
    return null;
  }

  static String? _joinName(String? first, String? last) {
    final f = first?.trim() ?? '';
    final l = last?.trim() ?? '';
    final full = [f, l].where((s) => s.isNotEmpty).join(' ');
    return full.isEmpty ? null : full;
  }

  static ({String? personName, String? email, String? phone, String? mobile})
  _pickPrimaryContactPerson(Map<String, Object?> json) {
    final cpsRaw = _readList(json['contact_persons']);
    if (cpsRaw == null || cpsRaw.isEmpty) {
      return (personName: null, email: null, phone: null, mobile: null);
    }

    // Prefer is_primary_contact == true, else first item.
    Map<String, Object?>? primary;
    for (final item in cpsRaw) {
      final m = _readMap(item);
      if (m == null) continue;
      final isPrimary = m['is_primary_contact'];
      if (isPrimary is bool && isPrimary == true) {
        primary = m;
        break;
      }
    }
    primary ??= _readMap(cpsRaw.first);

    if (primary == null) {
      return (personName: null, email: null, phone: null, mobile: null);
    }

    final first = _readString(primary['first_name']);
    final last = _readString(primary['last_name']);

    return (
      personName: _joinName(first, last),
      email: _readString(primary['email']),
      phone: _readString(primary['phone']),
      mobile: _readString(primary['mobile']),
    );
  }

  // ─────────────────────────────────────────────
  // Mapping
  // ─────────────────────────────────────────────

  factory ZohoContact.fromJson(Map<String, dynamic> json) {
    final j = json.cast<String, Object?>();

    final id = _readString(j['contact_id']) ?? '';
    final display = _readString(j['contact_name']) ?? '';

    final primary = _pickPrimaryContactPerson(j);

    // Zoho sometimes returns email/phone/mobile at top-level too — use them as fallback.
    final email = primary.email ?? _readString(j['email']);
    final phone = primary.phone ?? _readString(j['phone']);
    final mobile = primary.mobile ?? _readString(j['mobile']);

    return ZohoContact(
      contactId: id,
      displayName: display,
      personName: primary.personName,
      companyName: _readString(j['company_name']),
      email: email,
      phone: phone,
      mobile: mobile,
      status: _readString(j['status']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    final d = displayName.trim();
    final company = (companyName ?? '').trim();
    final person = (personName ?? '').trim();
    final emailV = (email ?? '').trim();
    final phoneV = (phone ?? '').trim();
    final mobileV = (mobile ?? '').trim();

    return <String, dynamic>{
      'contact_name': d,
      if (company.isNotEmpty) 'company_name': company,
      if (person.isNotEmpty) 'person_name': person,
      if (emailV.isNotEmpty) 'email': emailV,
      if (phoneV.isNotEmpty) 'phone': phoneV,
      if (mobileV.isNotEmpty) 'mobile': mobileV,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final d = displayName.trim();
    final company = (companyName ?? '').trim();
    final person = (personName ?? '').trim();
    final emailV = (email ?? '').trim();
    final phoneV = (phone ?? '').trim();
    final mobileV = (mobile ?? '').trim();

    return <String, dynamic>{
      if (d.isNotEmpty) 'contact_name': d,
      if (company.isNotEmpty) 'company_name': company,
      if (person.isNotEmpty) 'person_name': person,
      if (emailV.isNotEmpty) 'email': emailV,
      if (phoneV.isNotEmpty) 'phone': phoneV,
      if (mobileV.isNotEmpty) 'mobile': mobileV,
    };
  }

  ZohoContact copyWith({
    String? contactId,
    String? displayName,
    String? personName,
    String? companyName,
    String? email,
    String? phone,
    String? mobile,
    String? status,
  }) {
    return ZohoContact(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      personName: personName ?? this.personName,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      status: status ?? this.status,
    );
  }
}

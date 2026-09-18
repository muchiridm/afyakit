// lib/hq/users/super_admins/super_admin_model.dart

class SuperAdmin {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;

  const SuperAdmin({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
  });

  static String? _clean(String? s) {
    final v = s?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  factory SuperAdmin.fromJson(Map<String, dynamic> json) {
    final uid = (json['uid'] ?? json['id']).toString().trim();

    return SuperAdmin(
      uid: uid,
      email: _clean(json['email'] as String?)?.toLowerCase(),
      displayName: _clean(json['displayName'] as String?),
      phoneNumber: _clean(json['phoneNumber'] as String?),
      // Backend sends `photoURL`; keep field name idiomatic in Dart.
      photoUrl: _clean(json['photoURL'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{'uid': uid};

    final emailV = _clean(email)?.toLowerCase();
    final nameV = _clean(displayName);
    final phoneV = _clean(phoneNumber);
    final photoV = _clean(photoUrl);

    if (emailV != null) out['email'] = emailV;
    if (nameV != null) out['displayName'] = nameV;
    if (phoneV != null) out['phoneNumber'] = phoneV;
    if (photoV != null) out['photoURL'] = photoV;

    return out;
  }
}

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

  factory SuperAdmin.fromJson(Map<String, dynamic> json) {
    return SuperAdmin(
      uid: (json['uid'] ?? json['id']).toString(),
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      // Backend sends `photoURL`; keep field name idiomatic in Dart.
      photoUrl: json['photoURL'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoURL': photoUrl,
    };
  }
}

class SuperAdmin {
  final String uid;
  final String? email;
  final String? displayName;

  const SuperAdmin({required this.uid, this.email, this.displayName});

  factory SuperAdmin.fromJson(Map<String, dynamic> j) => SuperAdmin(
    uid: j['uid'] as String,
    email: j['email'] as String?,
    displayName: j['displayName'] as String?,
  );
}

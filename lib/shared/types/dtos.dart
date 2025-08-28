class InviteResult {
  final String uid;
  final bool authCreated;
  final bool membershipCreated;

  const InviteResult({
    required this.uid,
    required this.authCreated,
    required this.membershipCreated,
  });

  factory InviteResult.fromJson(Map<String, dynamic> j) => InviteResult(
    uid: (j['uid'] ?? '').toString(),
    authCreated: j['authCreated'] == true,
    membershipCreated: j['membershipCreated'] == true,
  );
}

class UpdateProfileRequest {
  final String? displayName;
  final String? phoneNumber;
  final String? avatarUrl;

  const UpdateProfileRequest({
    this.displayName,
    this.phoneNumber,
    this.avatarUrl,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    if ((displayName ?? '').trim().isNotEmpty)
      'displayName': displayName!.trim(),
    if ((phoneNumber ?? '').trim().isNotEmpty)
      'phoneNumber': phoneNumber!.trim(),
    if ((avatarUrl ?? '').trim().isNotEmpty) 'avatarUrl': avatarUrl!.trim(),
  };
}

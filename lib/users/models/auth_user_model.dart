import 'package:afyakit/shared/utils/normalize/normalize_date.dart';

class AuthUser {
  final String uid;
  final String email;
  final String? phoneNumber;
  final String status;
  final String tenantId;
  final DateTime? invitedOn;
  final DateTime? activatedOn;
  final Map<String, dynamic>? claims;

  AuthUser({
    required this.uid,
    required this.email,
    required this.status,
    required this.tenantId,
    this.phoneNumber,
    this.invitedOn,
    this.activatedOn,
    this.claims,
  }) {
    // 🔒 Enforce at least one identifier
    final hasEmail = email.trim().isNotEmpty;
    final hasPhone = phoneNumber != null && phoneNumber!.trim().isNotEmpty;

    if (!hasEmail && !hasPhone) {
      throw ArgumentError(
        '❌ AuthUser must have at least an email or phone number',
      );
    }

    // 🔒 Enforce tenant ID
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('❌ AuthUser must have a valid tenantId');
    }
  }

  factory AuthUser.fromMap(String uid, Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString().trim();
    final phone = (json['phoneNumber'] ?? '').toString().trim();

    return AuthUser(
      uid: uid,
      email: email,
      phoneNumber: phone.isNotEmpty ? phone : null,
      status: json['status'] ?? 'invited',
      tenantId: json['tenantId'] ?? '',
      invitedOn: normalizeDate(json['invitedOn']),
      activatedOn: normalizeDate(json['activatedOn']),
      claims: json['claims'],
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final uid = json['uid']?.toString() ?? '';
    final email = (json['email'] ?? '').toString().trim();
    final phone = (json['phoneNumber'] ?? '').toString().trim();

    return AuthUser(
      uid: uid,
      email: email,
      phoneNumber: phone.isNotEmpty ? phone : null,
      status: json['status'] ?? 'invited',
      tenantId: json['tenantId'] ?? '',
      invitedOn: normalizeDate(json['invitedOn']),
      activatedOn: normalizeDate(json['activatedOn']),
      claims: json['claims'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'status': status,
      'tenantId': tenantId,
      'invitedOn': invitedOn?.toIso8601String(),
      'activatedOn': activatedOn?.toIso8601String(),
      if (claims != null) 'claims': claims,
    };
  }
}

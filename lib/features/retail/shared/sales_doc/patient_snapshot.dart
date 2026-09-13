// lib/features/retail/shared/sales_doc/patient_snapshot.dart

import 'package:afyakit/shared/utils/parse/primitives.dart';
import 'package:afyakit/shared/utils/utils.dart';

class SalesDocumentPatientSnapshot {
  const SalesDocumentPatientSnapshot({
    required this.profileId,
    required this.fullName,
    this.patientNo,
    this.dob,
    this.gender,
    this.relationship,
    this.membershipId,
    this.memberNo,
    this.scheme,
    this.payerName,
  });

  /// Canonical AfyaKit Health Profile ID.
  ///
  /// The snapshot represents the person in their contextual role as a patient,
  /// while the underlying entity reference remains the Health Profile.
  final String profileId;

  /// Optional insurer / external patient number.
  ///
  /// This is not the canonical AfyaKit identifier.
  final String? patientNo;

  final String fullName;

  final String? dob;
  final String? gender;
  final String? relationship;

  /// Insurance/member context when relevant.
  final String? membershipId;
  final String? memberNo;
  final String? scheme;
  final String? payerName;

  factory SalesDocumentPatientSnapshot.fromJson(JsonMap j) {
    return SalesDocumentPatientSnapshot(
      profileId: _asTrimmed(j['profile_id']),
      patientNo: _asCleanOrNull(j['patient_no']),
      fullName: _asTrimmed(j['full_name']),
      dob: _asCleanOrNull(j['dob']),
      gender: _asCleanOrNull(j['gender']),
      relationship: _asCleanOrNull(j['relationship']),
      membershipId: _asCleanOrNull(j['membership_id']),
      memberNo: _asCleanOrNull(j['member_no']),
      scheme: _asCleanOrNull(j['scheme']),
      payerName: _asCleanOrNull(j['payer_name']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'profile_id': profileId,
      'patient_no': patientNo,
      'full_name': fullName,
      'dob': dob,
      'gender': gender,
      'relationship': relationship,
      'membership_id': membershipId,
      'member_no': memberNo,
      'scheme': scheme,
      'payer_name': payerName,
    }..removeWhere(_removeEmpty);
  }

  SalesDocumentPatientSnapshot copyWith({
    String? profileId,
    String? patientNo,
    bool clearPatientNo = false,
    String? fullName,
    String? dob,
    bool clearDob = false,
    String? gender,
    bool clearGender = false,
    String? relationship,
    bool clearRelationship = false,
    String? membershipId,
    bool clearMembershipId = false,
    String? memberNo,
    bool clearMemberNo = false,
    String? scheme,
    bool clearScheme = false,
    String? payerName,
    bool clearPayerName = false,
  }) {
    return SalesDocumentPatientSnapshot(
      profileId: profileId ?? this.profileId,
      patientNo: clearPatientNo ? null : (patientNo ?? this.patientNo),
      fullName: fullName ?? this.fullName,
      dob: clearDob ? null : (dob ?? this.dob),
      gender: clearGender ? null : (gender ?? this.gender),
      relationship: clearRelationship
          ? null
          : (relationship ?? this.relationship),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      memberNo: clearMemberNo ? null : (memberNo ?? this.memberNo),
      scheme: clearScheme ? null : (scheme ?? this.scheme),
      payerName: clearPayerName ? null : (payerName ?? this.payerName),
    );
  }

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  static String _asTrimmed(Object? value) {
    final String text = asTrimmedString(value);
    return text.isEmpty ? '' : text;
  }

  static String? _asCleanOrNull(Object? value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}

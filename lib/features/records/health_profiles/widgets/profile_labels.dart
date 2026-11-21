// Pure presentation labels and relationship choices. No Flutter widgets.
import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';

class ProfilesLabels {
  const ProfilesLabels._();

  static const List<ProfileContactRelationship> selfLinkRelationships = [
    ProfileContactRelationship.self,
    ProfileContactRelationship.child,
    ProfileContactRelationship.spouse,
    ProfileContactRelationship.parent,
    ProfileContactRelationship.guardian,
  ];

  static const List<ProfileContactRelationship> payerRequestRelationships = [
    ProfileContactRelationship.insurance,
    ProfileContactRelationship.other,
  ];

  static const List<ProfileContactRelationship> staffLinkRelationships = [
    ProfileContactRelationship.self,
    ProfileContactRelationship.child,
    ProfileContactRelationship.spouse,
    ProfileContactRelationship.parent,
    ProfileContactRelationship.guardian,
    ProfileContactRelationship.insurance,
    ProfileContactRelationship.other,
  ];

  static String relationship(ProfileContactRelationship value) {
    switch (value) {
      case ProfileContactRelationship.self:
        return 'Self';
      case ProfileContactRelationship.child:
        return 'Child';
      case ProfileContactRelationship.spouse:
        return 'Spouse';
      case ProfileContactRelationship.parent:
        return 'Parent';
      case ProfileContactRelationship.guardian:
        return 'Guardian';
      case ProfileContactRelationship.insurance:
        return 'Insurance';
      case ProfileContactRelationship.other:
        return 'Other';
    }
  }

  /// On a profile detail view, the linked Contact is described relative
  /// to the patient; the stored relationship describes the patient relative
  /// to that Contact.
  static String profilePerspectiveRelationship(
    ProfileContactRelationship value,
  ) {
    switch (value) {
      case ProfileContactRelationship.child:
        return 'Parent';
      case ProfileContactRelationship.parent:
        return 'Child';
      case ProfileContactRelationship.self:
        return 'Self';
      case ProfileContactRelationship.spouse:
        return 'Spouse';
      case ProfileContactRelationship.guardian:
        return 'Guardian';
      case ProfileContactRelationship.insurance:
        return 'Insurer';
      case ProfileContactRelationship.other:
        return 'Other';
    }
  }

  static String gender(ProfileGender value) {
    switch (value) {
      case ProfileGender.male:
        return 'Male';
      case ProfileGender.female:
        return 'Female';
      case ProfileGender.other:
        return 'Other';
      case ProfileGender.unknown:
        return 'Unknown';
    }
  }

  static String status(ProfileLinkRequestStatus value) {
    switch (value) {
      case ProfileLinkRequestStatus.pendingOwnerApproval:
        return 'Pending owner approval';
      case ProfileLinkRequestStatus.pendingStaffApproval:
        return 'Pending staff approval';
      case ProfileLinkRequestStatus.approved:
        return 'Approved';
      case ProfileLinkRequestStatus.rejected:
        return 'Rejected';
      case ProfileLinkRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  static String approvalMode(ProfileLinkApprovalMode value) {
    switch (value) {
      case ProfileLinkApprovalMode.owner:
        return 'Owner approval';
      case ProfileLinkApprovalMode.staff:
        return 'Staff approval';
    }
  }

  static String nullable(String? value, {String fallback = '—'}) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }
}


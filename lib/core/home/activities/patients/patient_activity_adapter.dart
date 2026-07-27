// lib/core/home/activities/patients/patient_activity_adapter.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/core/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';

typedef ProfileActivityTapBuilder = VoidCallback? Function(Profile patient);

typedef ProfileLinkRequestActivityTapBuilder =
    VoidCallback? Function(ProfileLinkRequest request);

class ProfileActivityAdapter {
  const ProfileActivityAdapter._();

  static List<ActivityEntry> fromPatients(
    List<Profile> patients, {
    ProfileActivityTapBuilder? onTapForPatient,
  }) {
    return [
      for (final patient in patients)
        ActivityEntry(
          date: _patientActivityDate(patient),
          widget: ActivityEventTile(
            icon: Icons.person_outline,
            title: 'Patient profile • ${patient.fullName}',
            subtitle: _patientSubtitle(patient),
            timestamp: activityTimestampLabel(
              date: _patientActivityDate(patient),
              createdAt: patient.createdAt,
              updatedAt: patient.updatedAt,
            ),
            onTap: onTapForPatient?.call(patient),
          ),
        ),
    ];
  }

  static List<ActivityEntry> fromLinkRequests(
    List<ProfileLinkRequest> requests, {
    ProfileLinkRequestActivityTapBuilder? onTapForRequest,
  }) {
    return [
      for (final request in requests)
        ActivityEntry(
          date: _linkRequestActivityDate(request),
          widget: ActivityEventTile(
            icon: Icons.link_outlined,
            title: 'Patient link request • ${request.profileDisplayName}',
            subtitle: _linkRequestSubtitle(request),
            timestamp: activityTimestampLabel(
              date: _linkRequestActivityDate(request),
              createdAt: request.createdAt,
              updatedAt: request.updatedAt,
            ),
            onTap: onTapForRequest?.call(request),
          ),
        ),
    ];
  }

  static DateTime _patientActivityDate(Profile patient) {
    return patient.updatedAt ??
        patient.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime _linkRequestActivityDate(ProfileLinkRequest request) {
    return request.updatedAt ??
        request.approvedAt ??
        request.rejectedAt ??
        request.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _patientSubtitle(Profile patient) {
    final parts = <String>[];

    final relationship = patient.relationship;
    if (relationship != null) {
      parts.add(_relationshipLabel(relationship));
    }

    final contactName = (patient.contactDisplayName ?? '').trim();
    if (contactName.isNotEmpty) {
      parts.add(contactName);
    } else {
      final primary = patient.primaryLinkedContact;
      final primaryName = (primary?.contactDisplayName ?? '').trim();

      if (primaryName.isNotEmpty) {
        parts.add(primaryName);
      } else if (primary != null) {
        parts.add(_relationshipLabel(primary.relationship));
      }
    }

    if (!patient.isActive) parts.add('Inactive');

    if (parts.isEmpty) {
      return patient.updatedAt == null ? 'Profile created' : 'Profile updated';
    }

    return parts.join(' • ');
  }

  static String _linkRequestSubtitle(ProfileLinkRequest request) {
    final parts = <String>[
      _linkStatusLabel(request.status),
      _approvalModeLabel(request.approvalMode),
      _relationshipLabel(request.relationship),
    ];

    final target = request.bestTargetLabel.trim();
    if (target.isNotEmpty) parts.add(target);

    return parts.join(' • ');
  }

  static String _relationshipLabel(ProfileContactRelationship relationship) {
    return switch (relationship) {
      ProfileContactRelationship.self => 'Self',
      ProfileContactRelationship.child => 'Child',
      ProfileContactRelationship.spouse => 'Spouse',
      ProfileContactRelationship.parent => 'Parent',
      ProfileContactRelationship.guardian => 'Guardian',
      ProfileContactRelationship.insurance => 'Insurance',
      ProfileContactRelationship.other => 'Other',
    };
  }

  static String _approvalModeLabel(ProfileLinkApprovalMode mode) {
    return switch (mode) {
      ProfileLinkApprovalMode.owner => 'Owner approval',
      ProfileLinkApprovalMode.staff => 'Staff approval',
    };
  }

  static String _linkStatusLabel(ProfileLinkRequestStatus status) {
    return switch (status) {
      ProfileLinkRequestStatus.pendingOwnerApproval => 'Pending owner approval',
      ProfileLinkRequestStatus.pendingStaffApproval => 'Pending staff approval',
      ProfileLinkRequestStatus.approved => 'Approved',
      ProfileLinkRequestStatus.rejected => 'Rejected',
      ProfileLinkRequestStatus.cancelled => 'Cancelled',
    };
  }
}

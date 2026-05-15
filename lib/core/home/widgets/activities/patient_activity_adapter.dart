// lib/core/home/widgets/activities/patient_activity_adapter.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/widgets/activities/activity_event_tile.dart';
import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';

class PatientActivityAdapter {
  const PatientActivityAdapter._();

  static List<ActivityEntry> fromPatients(
    List<PatientProfile> patients, {
    VoidCallback? onTap,
  }) {
    return [
      for (final patient in patients)
        ActivityEntry(
          date: _patientActivityDate(patient),
          widget: ActivityEventTile(
            icon: Icons.person_outline,
            title: 'Patient profile • ${patient.fullName}',
            subtitle: _patientSubtitle(patient),
            onTap: onTap,
          ),
        ),
    ];
  }

  static List<ActivityEntry> fromLinkRequests(
    List<PatientLinkRequest> requests, {
    VoidCallback? onTap,
  }) {
    return [
      for (final request in requests)
        ActivityEntry(
          date: _linkRequestActivityDate(request),
          widget: ActivityEventTile(
            icon: Icons.link_outlined,
            title: 'Patient link request • ${request.patientDisplayName}',
            subtitle: _linkRequestSubtitle(request),
            onTap: onTap,
          ),
        ),
    ];
  }

  static DateTime _patientActivityDate(PatientProfile patient) {
    return patient.updatedAt ??
        patient.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime _linkRequestActivityDate(PatientLinkRequest request) {
    return request.updatedAt ??
        request.approvedAt ??
        request.rejectedAt ??
        request.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _patientSubtitle(PatientProfile patient) {
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

  static String _linkRequestSubtitle(PatientLinkRequest request) {
    final parts = <String>[
      _linkStatusLabel(request.status),
      _approvalModeLabel(request.approvalMode),
      _relationshipLabel(request.relationship),
    ];

    final target = request.bestTargetLabel.trim();
    if (target.isNotEmpty) parts.add(target);

    return parts.join(' • ');
  }

  static String _relationshipLabel(PatientContactRelationship relationship) {
    return switch (relationship) {
      PatientContactRelationship.self => 'Self',
      PatientContactRelationship.child => 'Child',
      PatientContactRelationship.spouse => 'Spouse',
      PatientContactRelationship.parent => 'Parent',
      PatientContactRelationship.guardian => 'Guardian',
      PatientContactRelationship.insurance => 'Insurance',
      PatientContactRelationship.other => 'Other',
    };
  }

  static String _approvalModeLabel(PatientLinkApprovalMode mode) {
    return switch (mode) {
      PatientLinkApprovalMode.owner => 'Owner approval',
      PatientLinkApprovalMode.staff => 'Staff approval',
    };
  }

  static String _linkStatusLabel(PatientLinkRequestStatus status) {
    return switch (status) {
      PatientLinkRequestStatus.pendingOwnerApproval => 'Pending owner approval',
      PatientLinkRequestStatus.pendingStaffApproval => 'Pending staff approval',
      PatientLinkRequestStatus.approved => 'Approved',
      PatientLinkRequestStatus.rejected => 'Rejected',
      PatientLinkRequestStatus.cancelled => 'Cancelled',
    };
  }
}

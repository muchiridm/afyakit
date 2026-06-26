// lib/core/home/activities/patients/patient_activity_providers.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';

const Duration patientActivityRefreshInterval = Duration(seconds: 15);

class StaffPatientActivityBundle {
  const StaffPatientActivityBundle({
    required this.patients,
    required this.linkRequests,
  });

  final List<PatientProfile> patients;
  final List<PatientLinkRequest> linkRequests;
}

final staffPatientActivityProvider =
    StreamProvider.autoDispose<StaffPatientActivityBundle>((ref) {
      return _pollStaffPatients(ref);
    });

final memberPatientActivityProvider = StreamProvider.autoDispose
    .family<List<PatientProfile>, String>((ref, contactId) {
      final cleanContactId = contactId.trim();

      if (cleanContactId.isEmpty) {
        return Stream.value(const <PatientProfile>[]);
      }

      return _pollMemberPatients(ref, contactId: cleanContactId);
    });

Stream<StaffPatientActivityBundle> _pollStaffPatients(Ref ref) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(patientProfilesServiceReadyProvider.future);

    final results = await Future.wait<Object>([
      service.list(perPage: 50, page: 1),
      service.listLinkRequests(perPage: 50, page: 1),
    ]);

    if (cancelled) return;

    yield StaffPatientActivityBundle(
      patients: results[0] as List<PatientProfile>,
      linkRequests: results[1] as List<PatientLinkRequest>,
    );

    await Future<void>.delayed(patientActivityRefreshInterval);
  }
}

Stream<List<PatientProfile>> _pollMemberPatients(
  Ref ref, {
  required String contactId,
}) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(patientProfilesServiceReadyProvider.future);

    final patients = await service.list(
      contactId: contactId,
      perPage: 50,
      page: 1,
    );

    if (cancelled) return;

    yield patients;

    await Future<void>.delayed(patientActivityRefreshInterval);
  }
}

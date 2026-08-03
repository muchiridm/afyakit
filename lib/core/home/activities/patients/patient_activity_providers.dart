// lib/core/home/activities/patients/patient_activity_providers.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/services/profiles_service.dart';

const Duration patientActivityRefreshInterval = Duration(seconds: 15);

class StaffPatientActivityBundle {
  const StaffPatientActivityBundle({
    required this.patients,
    required this.linkRequests,
  });

  final List<Profile> patients;
  final List<ProfileLinkRequest> linkRequests;
}

final staffPatientActivityProvider =
    StreamProvider.autoDispose<StaffPatientActivityBundle>((ref) {
      return _pollStaffPatients(ref);
    });

final memberPatientActivityProvider = StreamProvider.autoDispose
    .family<List<Profile>, String>((ref, contactId) {
      final cleanContactId = contactId.trim();

      if (cleanContactId.isEmpty) {
        return Stream.value(const <Profile>[]);
      }

      return _pollMemberPatients(ref, contactId: cleanContactId);
    });

Stream<StaffPatientActivityBundle> _pollStaffPatients(Ref ref) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(profilesServiceReadyProvider.future);

    final results = await Future.wait<Object>([
      service.list(perPage: 50, page: 1),
      service.listLinkRequests(perPage: 50, page: 1),
    ]);

    if (cancelled) return;

    yield StaffPatientActivityBundle(
      patients: results[0] as List<Profile>,
      linkRequests: results[1] as List<ProfileLinkRequest>,
    );

    await Future<void>.delayed(patientActivityRefreshInterval);
  }
}

Stream<List<Profile>> _pollMemberPatients(
  Ref ref, {
  required String contactId,
}) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(profilesServiceReadyProvider.future);

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

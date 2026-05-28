// lib/features/clinical/prescriptions/providers/prescriptions_providers.dart

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final prescriptionsServiceProvider = Provider<PrescriptionsService>((ref) {
  final api = ref.afyakitClient;
  final routes = ref.afyakitRoutes;

  return PrescriptionsService(api: api, routes: routes);
});

final prescriptionsControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String?>((
      ref,
      patientId,
    ) {
      final service = ref.watch(prescriptionsServiceProvider);

      final controller = PrescriptionsController(
        service: service,
        patientId: patientId,
      );

      final pid = patientId?.trim();

      if (pid != null && pid.isNotEmpty) {
        Future.microtask(() {
          controller.load(patientId: pid);
        });
      }
      return controller;
    });

final prescriptionPickerControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String>((
      ref,
      patientId,
    ) {
      final service = ref.watch(prescriptionsServiceProvider);
      final pid = patientId.trim();

      final controller = PrescriptionsController(
        service: service,
        patientId: pid,
      );

      if (pid.isNotEmpty) {
        Future<void>.microtask(() {
          controller.load(patientId: pid, isActive: true);
        });
      }

      return controller;
    });

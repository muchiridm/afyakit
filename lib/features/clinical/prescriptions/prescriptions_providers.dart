// lib/features/clinical/prescriptions/prescriptions_providers.dart

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────

final prescriptionsServiceProvider = Provider<PrescriptionsService>((ref) {
  return PrescriptionsService(
    api: ref.afyakitClient,
    routes: ref.afyakitRoutes,
    appId: ref.watch(appIdProvider),
  );
});

// ─────────────────────────────────────────────
// Prescriptions controller
// ─────────────────────────────────────────────

final prescriptionsControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String?>((
      ref,
      profileId,
    ) {
      final service = ref.watch(prescriptionsServiceProvider);

      final cleanProfileId = profileId?.trim();

      final controller = PrescriptionsController(
        service: service,
        profileId: cleanProfileId,
      );

      var disposed = false;

      ref.onDispose(() {
        disposed = true;
      });

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        Future<void>.microtask(() async {
          if (disposed) return;

          await controller.load(profileId: cleanProfileId);
        });
      }

      return controller;
    });

// ─────────────────────────────────────────────
// Prescription picker controller
// ─────────────────────────────────────────────

final prescriptionPickerControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String>((
      ref,
      profileId,
    ) {
      final service = ref.watch(prescriptionsServiceProvider);

      final cleanProfileId = profileId.trim();

      final controller = PrescriptionsController(
        service: service,
        profileId: cleanProfileId,
      );

      var disposed = false;

      ref.onDispose(() {
        disposed = true;
      });

      if (cleanProfileId.isNotEmpty) {
        Future<void>.microtask(() async {
          if (disposed) return;

          await controller.load(profileId: cleanProfileId, isActive: true);
        });
      }

      return controller;
    });

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final user = ref.watch(currentUserValueProvider);
  final appId = ref.watch(appIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final api = ref.watch(afyakitClientProvider);
  if (api == null) throw StateError('API client unavailable');
  final routes = ref.watch(afyakitRoutesProvider);
  return PrescriptionsService(
    isCurrent: () =>
        !disposed &&
        uid != null &&
        user?.uid == uid &&
        user?.status == UserStatus.active &&
        user?.hasActiveAppMembership(appId) == true &&
        FirebaseAuth.instance.currentUser?.uid == uid,
    api: api,
    routes: routes,
    appId: appId,
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

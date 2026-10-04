import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/storage/document_app_provider.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final prescriptionsServiceProvider = Provider<PrescriptionsService>((ref) {
  return PrescriptionsService(api: ref.afyakitClient, routes: ref.afyakitRoutes,
    appId: ref.watch(documentAppIdProvider));
});
final prescriptionsControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String?>((ref, profileId) {
  final service = ref.watch(prescriptionsServiceProvider);
  final cleanProfileId = profileId?.trim();
  final controller = PrescriptionsController(service: service, profileId: cleanProfileId);
  var disposed = false;
  ref.onDispose(() { disposed = true; });
  if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
    Future<void>.microtask(() {
      if (!disposed) controller.load(profileId: cleanProfileId);
    });
  }
  return controller;
});
final prescriptionPickerControllerProvider = StateNotifierProvider.autoDispose
    .family<PrescriptionsController, PrescriptionsState, String>((ref, profileId) {
  final service = ref.watch(prescriptionsServiceProvider);
  final cleanProfileId = profileId.trim();
  final controller = PrescriptionsController(service: service, profileId: cleanProfileId);
  var disposed = false;
  ref.onDispose(() { disposed = true; });
  if (cleanProfileId.isNotEmpty) {
    Future<void>.microtask(() {
      if (!disposed) controller.load(profileId: cleanProfileId, isActive: true);
    });
  }
  return controller;
});

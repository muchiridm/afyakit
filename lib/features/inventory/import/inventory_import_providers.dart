import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'inventory_import_service.dart';

final inventoryImportServiceProvider = FutureProvider.autoDispose<InventoryImportService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  ref.watch(appIdProvider);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryImportService(dio: client.dio, routes: AfyaKitRoutes(tenantId));
});

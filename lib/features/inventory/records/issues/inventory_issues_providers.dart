import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'inventory_issue.dart';
import 'inventory_issues_service.dart';

final inventoryIssuesServiceProvider = FutureProvider.autoDispose<InventoryIssuesService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);
  await ref.watch(tenantSessionGuardProvider.future);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryIssuesService(dio: client.dio, routes: AfyaKitRoutes(tenantId), appId: appId);
});
final inventoryIssuesProvider = FutureProvider.autoDispose<List<InventoryIssue>>((ref) async {
  final service = await ref.watch(inventoryIssuesServiceProvider.future);
  return service.listAll();
});
final inventoryIssueProvider = FutureProvider.autoDispose.family<InventoryIssue, String>((ref, id) async {
  final service = await ref.watch(inventoryIssuesServiceProvider.future);
  return service.get(id);
});

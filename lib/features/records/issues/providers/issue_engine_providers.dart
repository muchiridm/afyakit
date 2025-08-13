// lib/features/records/issues/providers/issue_policy_engine_provider.dart
import 'package:afyakit/features/records/issues/controllers/engines/cart_engine.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_policy_engine.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_form_engine.dart';
import 'package:afyakit/features/records/issues/services/issue_service.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final issuePolicyEngineProvider = Provider<IssuePolicyEngine>(
  (ref) => IssuePolicyEngine(),
);

final cartEngineProvider = Provider<CartEngine>((ref) => CartEngine());

final issueFormEngineProvider = Provider<IssueFormEngine>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return IssueFormEngine(IssueService(tenantId));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

/// Member scope adapter:
/// - Staff: null (unscoped)
/// - Member: accountNumber (hard-scope)
final zohoContactsAccountScopeProvider = Provider<String?>((ref) {
  final u = ref.watch(currentUserProvider).valueOrNull;
  if (u == null) return null;

  final acct = (u.accountNumber ?? '').trim();
  return acct.isEmpty ? null : acct;
});

/// Convenience: member mode = account scope exists
final zohoIsMemberModeProvider = Provider<bool>((ref) {
  final acct = (ref.watch(zohoContactsAccountScopeProvider) ?? '').trim();
  return acct.isNotEmpty;
});

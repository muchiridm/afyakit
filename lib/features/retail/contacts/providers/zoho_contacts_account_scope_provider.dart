// lib/features/retail/contacts/providers/zoho_contact_scope_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';

/// Member scope adapter:
/// - Staff: null (unscoped)
/// - Member: accountNumber (hard-scope)
final zohoContactsAccountScopeProvider = Provider<String?>((ref) {
  final mode = ref.watch(effectiveEntryModeProvider);

  // ✅ Only members are scoped.
  if (mode != EntryMode.member) return null;

  final u = ref.watch(currentUserProvider).valueOrNull;
  if (u == null) return null;

  final acct = (u.accountNumber ?? '').trim();
  return acct.isEmpty ? null : acct;
});

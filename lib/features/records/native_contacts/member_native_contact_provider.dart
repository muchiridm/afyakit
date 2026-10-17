import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';

/// Current member's tenant-canonical Native Contact account number.
///
/// This is a UI convenience, not an authorisation decision. The API verifies
/// ownership, app enrolment and the account reservation independently.
final currentMemberAccountNumberProvider = Provider<String?>((ref) {
  if (ref.watch(effectiveEntryModeProvider) != EntryMode.member) {
    return null;
  }

  final user = ref.watch(currentUserProvider).valueOrNull;
  final accountNumber = user?.accountNumber?.trim();
  if (accountNumber == null || accountNumber.isEmpty) return null;
  return accountNumber;
});

// lib/features/retail/contacts/zoho_contacts_providers.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';

@immutable
class ZohoMemberCustomerScope {
  const ZohoMemberCustomerScope({required this.accountNumber, this.contactId});

  final String accountNumber;
  final String? contactId;

  bool get hasAccountNumber => accountNumber.trim().isNotEmpty;
  bool get hasContactId => (contactId ?? '').trim().isNotEmpty;

  String get bindKey {
    final cid = (contactId ?? '').trim();
    if (cid.isNotEmpty) return 'id:$cid';

    final acct = accountNumber.trim();
    return acct.isNotEmpty ? 'acct:$acct' : '';
  }

  String get debugLabel {
    return 'ZohoMemberCustomerScope(accountNumber=$accountNumber, contactId=${contactId ?? ''}, bindKey=$bindKey)';
  }
}

/// Member customer scope adapter:
/// - Staff: null
/// - Member: account number + optional Zoho contact id
///
/// The contact id is the fast path for member quote/customer binding.
/// The account number remains the fallback and backend scope guard.
final zohoMemberCustomerScopeProvider = Provider<ZohoMemberCustomerScope?>((
  ref,
) {
  final mode = ref.watch(effectiveEntryModeProvider);

  // Only members are scoped.
  if (mode != EntryMode.member) {
    if (kDebugMode) {
      debugPrint('[zohoMemberCustomerScope] mode=$mode → null');
    }
    return null;
  }

  final u = ref.watch(currentUserProvider).valueOrNull;
  if (u == null) {
    if (kDebugMode) {
      debugPrint('[zohoMemberCustomerScope] currentUser=null → null');
    }
    return null;
  }

  final acct = (u.accountNumber ?? u.zoho?.accountNumber ?? '').trim();
  final contactId = (u.zoho?.contactId ?? '').trim();

  if (kDebugMode) {
    debugPrint(
      '[zohoMemberCustomerScope] '
      'uid=${u.uid} '
      'acct=$acct '
      'contactId=$contactId '
      'hasZoho=${u.zoho != null}',
    );
  }

  if (acct.isEmpty) return null;

  return ZohoMemberCustomerScope(
    accountNumber: acct,
    contactId: contactId.isEmpty ? null : contactId,
  );
});

/// Builds a lightweight member customer contact from the current session.
///
/// This is an optimistic local contact used to make member quote binding
/// instant. The backend remains the authority and can still refresh/validate
/// the contact in the background.
final currentMemberZohoContactProvider = Provider<ZohoContact?>((ref) {
  final scope = ref.watch(zohoMemberCustomerScopeProvider);
  if (scope == null) return null;

  final contactId = (scope.contactId ?? '').trim();
  final accountNumber = scope.accountNumber.trim();

  if (contactId.isEmpty || accountNumber.isEmpty) return null;

  final u = ref.watch(currentUserProvider).valueOrNull;
  if (u == null) return null;

  final computedName = u.computedDisplayName.trim();
  final companyName = (u.companyName ?? '').trim();

  final displayName = computedName.isNotEmpty
      ? computedName
      : companyName.isNotEmpty
      ? companyName
      : accountNumber;

  return ZohoContact(
    contactId: contactId,
    displayName: displayName,
    companyName: companyName.isEmpty ? null : companyName,
    accountNumber: accountNumber,
    contactType: u.zoho?.contactType ?? 'customer',
    status: u.zoho?.status ?? 'active',
  );
});

/// Member scope adapter:
/// - Staff: null (unscoped)
/// - Member: accountNumber (hard-scope)
///
/// Kept for existing contact list/search code.
final zohoContactsAccountScopeProvider = Provider<String?>((ref) {
  final scope = ref.watch(zohoMemberCustomerScopeProvider);
  return scope?.accountNumber;
});

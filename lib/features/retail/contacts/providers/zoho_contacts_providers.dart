// lib/features/retail/contacts/providers/zoho_contacts_providers.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';

@immutable
class ZohoMemberCustomerScope {
  const ZohoMemberCustomerScope({required this.accountNumber, this.contactId});

  final String accountNumber;
  final String? contactId;

  String get cleanAccountNumber => accountNumber.trim();
  String? get cleanContactId {
    final id = contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool get hasAccountNumber => cleanAccountNumber.isNotEmpty;
  bool get hasContactId => cleanContactId != null;
  bool get isValid => hasAccountNumber;

  String get bindKey {
    final cid = cleanContactId;
    if (cid != null) return 'id:$cid';

    final acct = cleanAccountNumber;
    return acct.isNotEmpty ? 'acct:$acct' : '';
  }

  String get debugLabel {
    return 'ZohoMemberCustomerScope('
        'accountNumber=$cleanAccountNumber, '
        'contactId=${cleanContactId ?? ''}, '
        'bindKey=$bindKey'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ZohoMemberCustomerScope &&
            other.cleanAccountNumber == cleanAccountNumber &&
            other.cleanContactId == cleanContactId;
  }

  @override
  int get hashCode => Object.hash(cleanAccountNumber, cleanContactId);
}

/// Member customer scope adapter:
/// - Staff: null
/// - Member: account number + optional Zoho contact id
///
/// The contact id is only a fast-path hint. It must still be validated against
/// the backend before being treated as a real Zoho contact.
final zohoMemberCustomerScopeProvider = Provider<ZohoMemberCustomerScope?>((
  ref,
) {
  final mode = ref.watch(effectiveEntryModeProvider);

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

/// Lightweight local member contact.
///
/// Important:
/// This does NOT create or validate a Zoho contact.
/// It is only useful as a temporary UI fallback.
final currentMemberZohoContactProvider = Provider<ZohoContact?>((ref) {
  final scope = ref.watch(zohoMemberCustomerScopeProvider);
  if (scope == null || !scope.isValid) return null;

  final contactId = scope.cleanContactId;
  final accountNumber = scope.cleanAccountNumber;

  if (contactId == null || accountNumber.isEmpty) return null;

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

/// Real member customer resolver.
///
/// This is the provider you should use when a quote/customer binding requires
/// an actual Zoho contact.
///
/// Resolution order:
/// 1. If user has contactId, validate it with backend.
/// 2. If not found, search by account number.
/// 3. If still not found, create a real Zoho customer contact.
/// 4. Return the real backend/Zoho contact.
final currentResolvedMemberZohoContactProvider =
    FutureProvider.autoDispose<ZohoContact?>((ref) async {
      final scope = ref.watch(zohoMemberCustomerScopeProvider);
      if (scope == null || !scope.isValid) return null;

      final u = ref.watch(currentUserProvider).valueOrNull;
      if (u == null) return null;

      final service = await ref.watch(zohoContactsServiceProvider.future);

      final contactId = scope.cleanContactId;
      final accountNumber = scope.cleanAccountNumber;

      // 1. Fast path: validate stored contactId.
      if (contactId != null) {
        final byId = await service.getLightOrNull(contactId);

        if (byId != null) {
          final acct = (byId.accountNumber ?? '').trim();

          // Accept if account number matches, or if Zoho contact exists but
          // account number is missing. The backend can later patch/enrich it.
          if (acct.isEmpty || acct == accountNumber) {
            return byId;
          }

          if (kDebugMode) {
            debugPrint(
              '[currentResolvedMemberZohoContact] '
              'contactId=$contactId exists but account mismatch: '
              'zohoAcct=$acct sessionAcct=$accountNumber',
            );
          }
        }
      }

      // 2. Fallback: find by deterministic account number.
      final byAccount = await service.getByAccountNumber(
        accountNumber,
        forceRefresh: true,
      );

      if (byAccount != null) return byAccount;

      // 3. Last resort: create a real Zoho customer contact.
      final computedName = u.computedDisplayName.trim();
      final companyName = (u.companyName ?? '').trim();

      final displayName = computedName.isNotEmpty
          ? computedName
          : companyName.isNotEmpty
          ? companyName
          : accountNumber;

      final draft = ZohoContact(
        contactId: '',
        displayName: displayName,
        companyName: companyName.isEmpty ? null : companyName,
        accountNumber: accountNumber,
        contactType: 'customer',
        status: 'active',
      );

      final created = await service.create(draft);

      if (kDebugMode) {
        debugPrint(
          '[currentResolvedMemberZohoContact] '
          'created real Zoho contact: '
          'contactId=${created.contactId} '
          'accountNumber=${created.accountNumber}',
        );
      }

      return created;
    });

/// Member account scope adapter:
/// - Staff: null
/// - Member: accountNumber
///
/// Kept for existing contact list/search code.
final zohoContactsAccountScopeProvider = Provider<String?>((ref) {
  final scope = ref.watch(zohoMemberCustomerScopeProvider);
  return scope?.cleanAccountNumber;
});

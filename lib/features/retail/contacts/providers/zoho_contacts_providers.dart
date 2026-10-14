// lib/features/records/zoho_contacts/providers/zoho_contacts_providers.dart
// Accounting projection only. No Zoho contact creation or account-number lookup.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';

/// The trusted member's canonical Native Contact ID (AC-XXXXXX).
/// Null in staff mode, while the session is loading, or when unlinked.
final currentMemberNativeContactIdProvider = Provider<String?>((ref) {
  if (ref.watch(effectiveEntryModeProvider) != EntryMode.member) {
    return null;
  }

  final user = ref.watch(currentUserProvider).valueOrNull;
  final id = user?.nativeContactId?.trim();
  return (id == null || id.isEmpty) ? null : id;
});

/// Optional Zoho mapping for an already linked Native Contact.
/// A missing mapping is not an instruction to create a Zoho customer.
/// Only use this in flows that genuinely need Zoho accounting data.
final currentMemberZohoMappingProvider =
    FutureProvider.autoDispose<ZohoContactMapping?>((ref) async {
      final nativeId = ref.watch(currentMemberNativeContactIdProvider);
      if (nativeId == null) return null;

      final service = await ref.watch(zohoContactsServiceProvider.future);
      try {
        final mapping = await service.getMapping(nativeId);
        if (mapping.nativeContactId != nativeId) {
          throw StateError(
            'Zoho mapping does not match the current Native Contact',
          );
        }
        return mapping;
      } catch (error) {
        // Do not hide auth, network or server errors as "no mapping".
        rethrow;
      }
    });

/// Accounting customer detail, not the app's authoritative customer identity.
final currentMemberMappedZohoContactProvider =
    FutureProvider.autoDispose<ZohoMappedContact?>((ref) async {
      final nativeId = ref.watch(currentMemberNativeContactIdProvider);
      if (nativeId == null) return null;

      final service = await ref.watch(zohoContactsServiceProvider.future);
      final contact = await service.getMappedContact(nativeId);
      if (contact.nativeContactId != nativeId) {
        throw StateError(
          'Zoho customer does not match the current Native Contact',
        );
      }
      return contact;
    });

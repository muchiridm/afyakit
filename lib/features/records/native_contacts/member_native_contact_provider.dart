import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';

/// UI convenience only; not proof of ownership. The server authenticates all /me calls.
final currentMemberAccountNumberProvider = Provider<String?>((ref) {
  if (ref.watch(effectiveEntryModeProvider) != EntryMode.member) return null;
  final account = ref
      .watch(currentUserProvider)
      .valueOrNull
      ?.accountNumber
      ?.trim()
      .toUpperCase();
  if (account == null || account.isEmpty) return null;
  return account;
});

/// Only request member endpoints in member mode. No staff directory query.
final memberNativeContactProvider = FutureProvider.autoDispose<NativeContact>((
  ref,
) async {
  if (ref.watch(effectiveEntryModeProvider) != EntryMode.member) {
    throw StateError('My Contact is available in member mode only');
  }
  final service = await ref.watch(nativeContactsServiceProvider.future);
  return service.getMine();
});

/// Contact -> Profile relationship summaries only, never a grant to clinical records.
final memberLinkedHealthProfilesProvider =
    FutureProvider.autoDispose<List<Profile>>((ref) async {
      if (ref.watch(effectiveEntryModeProvider) != EntryMode.member) {
        throw StateError(
          'My Linked Health Profiles is available in member mode only',
        );
      }
      final service = await ref.watch(nativeContactsServiceProvider.future);
      return service.listMyLinkedHealthProfiles();
    });

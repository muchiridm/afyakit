// lib/core/home/providers/entry_mode_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';

/// Staff-only UI toggle: view the app as Staff UX or Member UX.
/// - Real user type remains staff; this is purely a UI preference.
/// - NOT autoDispose: must persist across navigation/rebuilds.
/// - Default is member so staff land in the normal customer/member UX first.
final staffViewModeProvider = StateProvider<EntryMode>((ref) {
  return EntryMode.member;
});

/// True if the current user is staff for this tenant (real permission),
/// regardless of UI view mode.
final isStaffUserProvider = Provider<bool>((ref) {
  final u = ref.watch(currentUserValueProvider);
  if (u == null) return false;
  return u.isStaffResolved == true;
});

/// Base entry mode from auth + membership (no UI toggle).
final baseEntryModeProvider = Provider<EntryMode>((ref) {
  final u = ref.watch(currentUserValueProvider);
  if (u == null) return EntryMode.guest;

  // Real staff permission.
  if (u.isStaffResolved == true) return EntryMode.staff;

  // Logged in but not staff.
  return EntryMode.member;
});

/// Effective entry mode = base mode, but staff can choose Staff or Member UX.
final effectiveEntryModeProvider = Provider<EntryMode>((ref) {
  final base = ref.watch(baseEntryModeProvider);

  // Only staff can toggle their view mode.
  if (base != EntryMode.staff) return base;

  final view = ref.watch(staffViewModeProvider);

  // Only allow member/staff as a staff view. Guard against accidental guest.
  return switch (view) {
    EntryMode.staff => EntryMode.staff,
    EntryMode.member => EntryMode.member,
    EntryMode.guest => EntryMode.member,
  };
});

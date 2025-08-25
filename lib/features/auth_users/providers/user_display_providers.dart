// lib/features/auth_users/providers/user_display_providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

/// Canonical: how to show a user nicely.
String userDisplayOf(AuthUser? u) => u == null
    ? ''
    : resolveUserDisplay(
        displayName: u.displayName,
        email: u.email,
        phone: u.phoneNumber,
        uid: u.uid,
      );

/// Fetch AuthUser by uid (tenant-scoped) with a short keepAlive window.
final authUserByIdProvider = FutureProvider.autoDispose
    .family<AuthUser?, String>((ref, uid) async {
      ref.watch(tenantIdProvider); // tenant-aware
      if (uid.isEmpty) return null;

      final link = ref.keepAlive();
      Timer(const Duration(minutes: 5), link.close);

      final um = ref.read(userManagerControllerProvider.notifier);
      return um.getUserById(uid);
    });

/// Friendly label for an arbitrary uid (name → email → phone → uid).
final userDisplayProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  uid,
) async {
  ref.watch(tenantIdProvider);
  if (uid.isEmpty) return '';

  final user = await ref.watch(authUserByIdProvider(uid).future);
  if (user != null) return userDisplayOf(user);

  // Fallback to Firebase user if this UID is self
  final me = fb.FirebaseAuth.instance.currentUser;
  if (me?.uid == uid) {
    return resolveUserDisplay(
      displayName: me?.displayName,
      email: me?.email,
      phone: me?.phoneNumber,
      uid: uid,
    );
  }
  return uid;
});

/// Current signed-in user’s display label (or null while loading).
final currentUserDisplayProvider = Provider.autoDispose<String?>((ref) {
  ref.watch(tenantIdProvider); // tenant-aware
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;

  final meAsync = ref.watch(authUserByIdProvider(uid));
  return meAsync.maybeWhen(data: (u) => userDisplayOf(u), orElse: () => null);
});

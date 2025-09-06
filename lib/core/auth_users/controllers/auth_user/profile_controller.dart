import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/controllers/auth_user/auth_user_controller.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/screens/home_screen/home_screen.dart';

@immutable
class ProfileScope {
  final String tenantId;
  final String? inviteUid;
  const ProfileScope({required this.tenantId, this.inviteUid});

  @override
  bool operator ==(Object other) =>
      other is ProfileScope &&
      other.tenantId == tenantId &&
      other.inviteUid == inviteUid;

  @override
  int get hashCode => Object.hash(tenantId, inviteUid);
}

class ProfileFormState {
  final bool loading;
  final String uid;
  final AuthUser? user;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool seeded;

  ProfileFormState({
    required this.loading,
    required this.uid,
    required this.user,
    required this.nameController,
    required this.phoneController,
    required this.seeded,
  });

  factory ProfileFormState.initial() => ProfileFormState(
    loading: true,
    uid: '',
    user: null,
    nameController: TextEditingController(),
    phoneController: TextEditingController(),
    seeded: false,
  );

  ProfileFormState copyWith({
    bool? loading,
    String? uid,
    AuthUser? user,
    TextEditingController? nameController,
    TextEditingController? phoneController,
    bool? seeded,
  }) {
    return ProfileFormState(
      loading: loading ?? this.loading,
      uid: uid ?? this.uid,
      user: user ?? this.user,
      nameController: nameController ?? this.nameController,
      phoneController: phoneController ?? this.phoneController,
      seeded: seeded ?? this.seeded,
    );
  }
}

final profileControllerProvider =
    AutoDisposeStateNotifierProviderFamily<
      ProfileController,
      ProfileFormState,
      ProfileScope
    >(
      (ref, scope) => ProfileController(
        ref,
        tenantId: scope.tenantId,
        inviteUid: scope.inviteUid,
      ),
    );

class ProfileController extends StateNotifier<ProfileFormState> {
  final Ref ref;
  final String tenantId;
  final String? inviteUid;

  bool _inited = false;

  ProfileController(this.ref, {required this.tenantId, this.inviteUid})
    : super(ProfileFormState.initial()) {
    ref.onDispose(() {
      state.nameController.dispose();
      state.phoneController.dispose();
    });
  }

  // Run work after the current frame/build cycle.
  void _afterFrame(VoidCallback fn) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  /// One-time setup. No claim checks. No sign-outs.
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    final sessionUser = await ref.read(currentUserFutureProvider.future);
    final resolvedUid = (inviteUid?.trim().isNotEmpty ?? false)
        ? inviteUid!.trim()
        : (sessionUser?.uid ?? '').trim();

    _afterFrame(() {
      state = state.copyWith(uid: resolvedUid, loading: false);
    });
    if (resolvedUid.isEmpty) return;

    // Keep UI in sync with the canonical user doc.
    ref.listen<AsyncValue<AuthUser?>>(authUserByIdProvider(resolvedUid), (
      prev,
      next,
    ) {
      if (!mounted) return;

      if (next.isLoading) {
        _afterFrame(() => state = state.copyWith(loading: true));
        return;
      }

      final user = next.valueOrNull;
      _afterFrame(() {
        state = state.copyWith(user: user, loading: false);
        if (!state.seeded && user != null) {
          state.nameController.text = user.displayName;
          state.phoneController.text = user.phoneNumber ?? '';
          state = state.copyWith(seeded: true);
        }
      });
    });

    // Optional gentle refresh of the doc (post-frame to avoid init-time invalidation).
    _afterFrame(() => ref.invalidate(authUserByIdProvider(resolvedUid)));
  }

  Future<void> changeAvatar(BuildContext context) async {
    final uid = state.uid;
    final user = state.user;
    if (uid.isEmpty || user == null) return;

    final newUrl = await DialogService.prompt(
      title: 'Update Avatar URL',
      initialValue: user.avatarUrl ?? '',
    );
    if (newUrl == null || newUrl.trim().isEmpty) return;

    await ref.read(authUserControllerProvider.notifier).updateFields(uid, {
      'avatarUrl': newUrl.trim(),
    });

    if (!mounted) return;
    _afterFrame(() => ref.invalidate(authUserByIdProvider(uid)));
    SnackService.showSuccess('Avatar updated');
  }

  /// Minimal save: persist → toast → go home → light cache invalidation (post-frame).
  Future<void> save(BuildContext context) async {
    final uid = state.uid;
    if (uid.isEmpty || !mounted) return;

    final name = state.nameController.text.trim();
    if (name.isEmpty) {
      SnackService.showError('Display name is required.');
      return;
    }
    final phone = state.phoneController.text.trim();

    state = state.copyWith(loading: true);

    try {
      await ref.read(authUserControllerProvider.notifier).updateFields(uid, {
        'displayName': name,
        'phoneNumber': phone,
      });

      if (!mounted) return;
      SnackService.showSuccess('Profile updated');

      // Navigate after the frame.
      _afterFrame(() {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      });

      // Background tidy-up (post-frame).
      _afterFrame(() {
        if (!mounted) return;
        ref.invalidate(authUserByIdProvider(uid));
        ref.invalidate(currentUserProvider);
        ref.invalidate(currentUserDisplayProvider);
      });
    } catch (_) {
      if (mounted) {
        SnackService.showError('Failed to update profile. Please try again.');
      }
    } finally {
      _afterFrame(() {
        if (mounted) state = state.copyWith(loading: false);
      });
    }
  }

  /// Simple “try again” that just nudges local providers (post-frame).
  Future<void> retrySync() async {
    final uid = state.uid;
    if (uid.isEmpty) return;
    _afterFrame(() {
      if (!mounted) return;
      ref.invalidate(authUserByIdProvider(uid));
      ref.invalidate(currentUserProvider);
      ref.invalidate(currentUserDisplayProvider);
    });
  }
}

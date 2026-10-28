// lib/features/hq/apps/domains/controllers/app_domains_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/domains/models/domain_binding.dart';
import 'package:afyakit/core/domains/services/app_domain_service.dart';

typedef AppDomainScope = ({String tenantId, String appId});

@immutable
class AppDomainsState {
  final bool loading;
  final bool busy;
  final String? error;
  final List<DomainBinding> domains;

  const AppDomainsState({
    this.loading = true,
    this.busy = false,
    this.error,
    this.domains = const <DomainBinding>[],
  });

  AppDomainsState copyWith({
    bool? loading,
    bool? busy,
    String? error,
    List<DomainBinding>? domains,
  }) {
    return AppDomainsState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: error,
      domains: domains ?? this.domains,
    );
  }
}

/// One controller instance per tenant/app pair.
final appDomainsControllerProvider =
    AutoDisposeStateNotifierProviderFamily<
      AppDomainsController,
      AppDomainsState,
      AppDomainScope
    >((ref, scope) {
      return AppDomainsController(
        ref,
        tenantId: scope.tenantId,
        appId: scope.appId,
      );
    });

class AppDomainsController extends StateNotifier<AppDomainsState> {
  AppDomainsController(
    this._ref, {
    required String tenantId,
    required String appId,
  }) : tenantId = tenantId.trim().toLowerCase(),
       appId = appId.trim().toLowerCase(),
       super(const AppDomainsState()) {
    unawaited(reload());
  }

  final AutoDisposeStateNotifierProviderRef<
    AppDomainsController,
    AppDomainsState
  >
  _ref;

  final String tenantId;
  final String appId;

  Future<AppDomainService> _svc() {
    return _ref.read(appDomainServiceProvider.future);
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final svc = await _svc();

      final list = await svc.listAppDomains(tenantId, appId);

      list.sort((a, b) {
        if (a.isPrimary != b.isPrimary) {
          return a.isPrimary ? -1 : 1;
        }

        if (a.verified != b.verified) {
          return a.verified ? -1 : 1;
        }

        return a.domain.compareTo(b.domain);
      });

      state = state.copyWith(loading: false, domains: list, error: null);
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  Future<void> addDomain(String domain) async {
    final cleanDomain = domain.trim().toLowerCase();

    if (cleanDomain.isEmpty) {
      return;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final svc = await _svc();

      await svc.addAppDomain(tenantId, appId, cleanDomain);

      await reload();
    } catch (error) {
      state = state.copyWith(error: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> verifyDomain(String domain) async {
    final cleanDomain = domain.trim().toLowerCase();

    if (cleanDomain.isEmpty) {
      return;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final svc = await _svc();

      await svc.verifyAppDomain(tenantId, appId, cleanDomain);

      await reload();
    } catch (error) {
      state = state.copyWith(error: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> setPrimary(String domain) async {
    final cleanDomain = domain.trim().toLowerCase();

    if (cleanDomain.isEmpty) {
      return;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final svc = await _svc();

      await svc.setPrimaryAppDomain(tenantId, appId, cleanDomain);

      await reload();
    } catch (error) {
      state = state.copyWith(error: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> setActive(String domain, bool active) async {
    final cleanDomain = domain.trim().toLowerCase();

    if (cleanDomain.isEmpty) {
      return;
    }

    final previous = state.domains;

    final optimistic = previous
        .map(
          (item) =>
              item.domain == cleanDomain ? item.copyWith(active: active) : item,
        )
        .toList();

    state = state.copyWith(domains: optimistic, busy: true, error: null);

    try {
      final svc = await _svc();

      await svc.setAppDomainActive(tenantId, appId, cleanDomain, active);

      await reload();
    } catch (error) {
      state = state.copyWith(domains: previous, error: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> removeDomain(String domain) async {
    final cleanDomain = domain.trim().toLowerCase();

    if (cleanDomain.isEmpty) {
      return;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final svc = await _svc();

      await svc.removeAppDomain(tenantId, appId, cleanDomain);

      await reload();
    } catch (error) {
      state = state.copyWith(error: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  // ─────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────

  Future<void> copy(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: cleanText));
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [AppDomainsController] '
          'copy failed: $error',
        );
      }
    }
  }
}

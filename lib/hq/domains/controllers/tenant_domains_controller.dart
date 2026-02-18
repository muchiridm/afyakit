// lib/hq/domains/controllers/tenant_domains_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/domains/models/domain_binding.dart';
import 'package:afyakit/hq/domains/services/tenant_domain_service.dart';

@immutable
class TenantDomainsState {
  final bool loading;
  final bool busy;
  final String? error;
  final List<DomainBinding> domains;

  const TenantDomainsState({
    this.loading = true,
    this.busy = false,
    this.error,
    this.domains = const <DomainBinding>[],
  });

  TenantDomainsState copyWith({
    bool? loading,
    bool? busy,
    String? error,
    List<DomainBinding>? domains,
  }) {
    return TenantDomainsState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: error,
      domains: domains ?? this.domains,
    );
  }
}

/// Family controller: one instance per tenant slug.
final tenantDomainsControllerProvider =
    AutoDisposeStateNotifierProviderFamily<
      TenantDomainsController,
      TenantDomainsState,
      String
    >((ref, slug) {
      return TenantDomainsController(ref, slug);
    });

class TenantDomainsController extends StateNotifier<TenantDomainsState> {
  TenantDomainsController(this._ref, this.slug)
    : super(const TenantDomainsState()) {
    // Load immediately
    unawaited(reload());
  }

  final AutoDisposeStateNotifierProviderRef<
    TenantDomainsController,
    TenantDomainsState
  >
  _ref;

  final String slug;

  Future<TenantDomainService> _svc() {
    // tenantDomainServiceProvider is a FutureProvider
    return _ref.read(tenantDomainServiceProvider.future);
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final svc = await _svc();
      final list = await svc.listTenantDomains(slug);

      // (optional) ensure deterministic ordering
      list.sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        if (a.verified != b.verified) return a.verified ? -1 : 1;
        return a.domain.compareTo(b.domain);
      });

      state = state.copyWith(loading: false, domains: list, error: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  // ─────────────────────────────────────────────
  // Actions (all mutate + reload)
  // ─────────────────────────────────────────────

  Future<void> addDomain(String domain) async {
    final d = domain.trim();
    if (d.isEmpty) return;

    state = state.copyWith(busy: true, error: null);
    try {
      final svc = await _svc();

      // add is idempotent: returns '' on domain-exists
      await svc.addTenantDomain(slug, d);

      // Always reload so UI sees current server truth
      await reload();
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> verifyDomain(String domain) async {
    final d = domain.trim();
    if (d.isEmpty) return;

    state = state.copyWith(busy: true, error: null);
    try {
      final svc = await _svc();
      await svc.verifyTenantDomain(slug, d);
      await reload();
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> setPrimary(String domain) async {
    final d = domain.trim();
    if (d.isEmpty) return;

    state = state.copyWith(busy: true, error: null);
    try {
      final svc = await _svc();
      await svc.setPrimaryTenantDomain(slug, d);
      await reload();
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> setActive(String domain, bool active) async {
    final d = domain.trim();
    if (d.isEmpty) return;

    // Optimistic update (so the switch feels snappy)
    final prev = state.domains;
    final next = prev
        .map((x) => x.domain == d ? x.copyWith(active: active) : x)
        .toList();
    state = state.copyWith(domains: next, busy: true, error: null);

    try {
      final svc = await _svc();
      await svc.setTenantDomainActive(slug, d, active);
      await reload();
    } catch (e) {
      // rollback if server rejected
      state = state.copyWith(domains: prev, error: '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> removeDomain(String domain) async {
    final d = domain.trim();
    if (d.isEmpty) return;

    state = state.copyWith(busy: true, error: null);
    try {
      final svc = await _svc();
      await svc.removeTenantDomain(slug, d);
      await reload();
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  // ─────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────

  Future<void> copy(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: t));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [TenantDomainsController] copy failed: $e');
      }
      // Don’t throw; copying should never brick the UI.
    }
  }
}

// lib/features/retail/contacts/controllers/contacts_controller.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/zoho_contact.dart';
import '../services/zoho_contacts_service.dart';
import '../widgets/contact_editor_sheet.dart';
import '../widgets/contact_sheet_models.dart';

class ContactsState {
  const ContactsState({
    this.loadingList = false,
    this.loadingDetail = false,
    this.saving = false,
    this.error,
    this.search = '',
    this.items = const <ZohoContact>[],
  });

  final bool loadingList;
  final bool loadingDetail;
  final bool saving;
  final String? error;

  final String search;
  final List<ZohoContact> items;

  bool get busy => loadingList || loadingDetail || saving;

  ContactsState copyWith({
    bool? loadingList,
    bool? loadingDetail,
    bool? saving,
    String? error,
    String? search,
    List<ZohoContact>? items,
  }) {
    return ContactsState(
      loadingList: loadingList ?? this.loadingList,
      loadingDetail: loadingDetail ?? this.loadingDetail,
      saving: saving ?? this.saving,
      error: error,
      search: search ?? this.search,
      items: items ?? this.items,
    );
  }
}

final contactsControllerProvider =
    StateNotifierProvider.autoDispose<ContactsController, ContactsState>((ref) {
      final ctl = ContactsController(ref);
      ctl.refresh(); // ok
      return ctl;
    });

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._ref) : super(const ContactsState());

  final Ref _ref;

  Timer? _debounce;

  // invalidate in-flight async work when disposed / when newer call starts
  int _token = 0;

  // list refresh ordering (ignore stale completes)
  int _refreshSeq = 0;

  bool get _alive => mounted;

  @override
  void dispose() {
    _token++;
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Search + list refresh
  // ─────────────────────────────────────────────

  void setSearch(String v) {
    if (!_alive) return;

    state = state.copyWith(search: v, error: null);

    _debounce?.cancel();
    final myToken = _token;

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!_alive) return;
      if (myToken != _token) return;
      refresh();
    });
  }

  Future<void> refresh() async {
    if (!_alive) return;

    final seq = ++_refreshSeq;
    final myToken = _token;

    // Don’t clobber a save with list loading UX.
    // Still allow refresh, but keep saving true if it’s in progress.
    state = state.copyWith(loadingList: true, error: null);

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final q = state.search.trim();
      final items = await svc.list(search: q.isEmpty ? null : q);

      if (!_alive) return;
      if (myToken != _token) return;
      if (seq != _refreshSeq) return;

      state = state.copyWith(loadingList: false, items: items);
    } catch (e) {
      if (!_alive) return;
      if (myToken != _token) return;
      if (seq != _refreshSeq) return;

      state = state.copyWith(loadingList: false, error: e.toString());
    }
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────

  Future<void> create(ZohoContact input) async {
    if (!_alive) return;
    final myToken = _token;

    state = state.copyWith(saving: true, error: null);

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final created = await svc.create(input);

      if (!_alive) return;
      if (myToken != _token) return;

      // Optimistic insert (fast UX)
      state = state.copyWith(
        saving: false,
        items: <ZohoContact>[created, ...state.items],
      );

      // If search is active, the optimistic insert may not match server search results.
      // Refresh silently to reconcile.
      if (state.search.trim().isNotEmpty) {
        unawaited(refresh());
      }
    } catch (e) {
      if (!_alive) return;
      if (myToken != _token) return;

      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> update(String contactId, ZohoContact input) async {
    if (!_alive) return;
    final myToken = _token;

    state = state.copyWith(saving: true, error: null);

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final updated = await svc.updateFromModel(contactId, input);

      if (!_alive) return;
      if (myToken != _token) return;

      final next = state.items
          .map((c) => c.contactId == contactId ? updated : c)
          .toList(growable: false);

      state = state.copyWith(saving: false, items: next);

      if (state.search.trim().isNotEmpty) {
        unawaited(refresh());
      }
    } catch (e) {
      if (!_alive) return;
      if (myToken != _token) return;

      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> delete(String contactId) async {
    if (!_alive) return;
    final myToken = _token;

    state = state.copyWith(saving: true, error: null);

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      await svc.delete(contactId);

      if (!_alive) return;
      if (myToken != _token) return;

      final next = state.items
          .where((c) => c.contactId != contactId)
          .toList(growable: false);

      state = state.copyWith(saving: false, items: next);

      if (state.search.trim().isNotEmpty) {
        unawaited(refresh());
      }
    } catch (e) {
      if (!_alive) return;
      if (myToken != _token) return;

      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // UI flows
  // ─────────────────────────────────────────────

  Future<void> openCreateFlow(BuildContext context) async {
    final res = await _openSheet(context, initial: null);
    if (res == null) return;

    await res.when(
      saveRequested: (draft) async {
        if (draft.displayName.trim().isEmpty) {
          _snack(context, 'Display name is required', isError: true);
          return;
        }

        try {
          await create(draft);
          _snack(context, 'Contact created');
        } catch (_) {
          _snack(context, 'Failed to create contact', isError: true);
        }
      },
      deleteRequested: (_) async {},
    );
  }

  Future<void> openExistingFlow(
    BuildContext context,
    ZohoContact contact,
  ) async {
    final detailed = await _loadDetailedContact(context, contact.contactId);
    if (detailed == null) return;

    if (!_alive) return;

    // keep cache fresh
    final next = state.items
        .map((c) => c.contactId == detailed.contactId ? detailed : c)
        .toList(growable: false);

    state = state.copyWith(items: next);

    final res = await _openSheet(context, initial: detailed);
    if (res == null) return;

    await res.when(
      saveRequested: (draft) async {
        if (draft.displayName.trim().isEmpty) {
          _snack(context, 'Display name is required', isError: true);
          return;
        }

        try {
          await update(detailed.contactId, draft);
          _snack(context, 'Contact updated');
        } catch (_) {
          _snack(context, 'Failed to update contact', isError: true);
        }
      },
      deleteRequested: (contactId) async {
        final ok = await _confirmDelete(context, detailed.displayName);
        if (ok != true) return;

        try {
          await delete(contactId);
          _snack(context, 'Contact deleted');
        } catch (_) {
          _snack(context, 'Failed to delete contact', isError: true);
        }
      },
    );
  }

  Future<ZohoContact?> _loadDetailedContact(
    BuildContext context,
    String contactId,
  ) async {
    if (!_alive) return null;
    if (state.saving) return null;

    final myToken = _token;

    state = state.copyWith(loadingDetail: true, error: null);

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final detailed = await svc.get(contactId);

      if (!_alive) return null;
      if (myToken != _token) return null;

      state = state.copyWith(loadingDetail: false);
      return detailed;
    } catch (e) {
      if (!_alive) return null;
      if (myToken != _token) return null;

      state = state.copyWith(loadingDetail: false, error: e.toString());
      _snack(context, 'Failed to load contact details', isError: true);
      return null;
    }
  }

  Future<ContactSheetResult?> _openSheet(
    BuildContext context, {
    required ZohoContact? initial,
  }) {
    return showModalBottomSheet<ContactSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ContactEditorSheet(initial: initial),
    );
  }

  void _snack(BuildContext context, String msg, {bool isError = false}) {
    if (!context.mounted) return;
    final bg = isError ? Theme.of(context).colorScheme.error : null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  Future<bool?> _confirmDelete(BuildContext context, String displayName) {
    final label = displayName.trim().isEmpty
        ? 'this contact'
        : '"$displayName"';
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('This will delete $label in Zoho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Tiny helper to avoid analyzer warnings without importing package:pedantic.
/// If you already have it, replace with `unawaited(...)` from it.
void unawaited(Future<void> f) {}

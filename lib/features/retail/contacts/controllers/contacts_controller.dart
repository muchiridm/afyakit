// lib/features/retail/contacts/controllers/contacts_controller.dart

import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/zoho_contact.dart';
import '../widgets/contact_editor_sheet.dart';
import '../widgets/contact_sheet_models.dart';

class ContactsState {
  const ContactsState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.search = '',
    this.items = const <ZohoContact>[],
  });

  final bool loading;
  final bool saving;
  final String? error;

  final String search;
  final List<ZohoContact> items;

  ContactsState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    String? search,
    List<ZohoContact>? items,
  }) {
    return ContactsState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: error,
      search: search ?? this.search,
      items: items ?? this.items,
    );
  }
}

final contactsControllerProvider =
    StateNotifierProvider.autoDispose<ContactsController, ContactsState>((ref) {
      return ContactsController(ref)..refresh();
    });

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._ref) : super(const ContactsState());

  final Ref _ref;

  // ─────────────────────────────────────────────
  // Basic state ops
  // ─────────────────────────────────────────────

  void setSearch(String v) {
    state = state.copyWith(search: v, error: null);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final items = await svc.list(
        search: state.search.trim().isEmpty ? null : state.search.trim(),
      );
      state = state.copyWith(loading: false, items: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ─────────────────────────────────────────────
  // CRUD (no UI)
  // ─────────────────────────────────────────────

  Future<void> create(ZohoContact input) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final created = await svc.create(input);
      state = state.copyWith(
        saving: false,
        items: <ZohoContact>[created, ...state.items],
      );
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> update(String contactId, ZohoContact input) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      final updated = await svc.update(contactId, input);

      final next = state.items
          .map((c) => c.contactId == contactId ? updated : c)
          .toList(growable: false);

      state = state.copyWith(saving: false, items: next);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> delete(String contactId) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);
      await svc.delete(contactId);

      final next = state.items
          .where((c) => c.contactId != contactId)
          .toList(growable: false);

      state = state.copyWith(saving: false, items: next);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // UI flows (controller owns dialogs/snacks)
  // ─────────────────────────────────────────────

  Future<void> openCreateFlow(BuildContext context) async {
    final res = await _openSheet(context, initial: null);
    if (res == null) return;

    await res.when(
      saveRequested: (draft) async {
        final display = draft.displayName.trim();
        if (display.isEmpty) {
          _snack(context, 'Display name is required');
          return;
        }

        try {
          await create(draft);
          _snack(context, 'Contact created');
        } catch (_) {
          _snack(context, 'Failed to create contact', isError: true);
        }
      },
      deleteRequested: (_) async {
        // shouldn’t happen on create sheet (no id), ignore
      },
    );
  }

  Future<void> openExistingFlow(
    BuildContext context,
    ZohoContact contact,
  ) async {
    final res = await _openSheet(context, initial: contact);
    if (res == null) return;

    await res.when(
      saveRequested: (draft) async {
        final display = draft.displayName.trim();
        if (display.isEmpty) {
          _snack(context, 'Display name is required');
          return;
        }

        try {
          await update(contact.contactId, draft);
          _snack(context, 'Contact updated');
        } catch (_) {
          _snack(context, 'Failed to update contact', isError: true);
        }
      },
      deleteRequested: (contactId) async {
        final ok = await _confirmDelete(context, contact.displayName);
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

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

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

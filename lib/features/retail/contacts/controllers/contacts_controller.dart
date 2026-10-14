import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/native_contacts/models/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/services/native_contacts_service.dart';
import '../widgets/contact_editor_sheet.dart';
import '../widgets/contact_sheet_models.dart';

class ContactsState {
  const ContactsState({
    this.loadingList = false,
    this.loadingDetail = false,
    this.saving = false,
    this.error,
    this.search = '',
    this.items = const [],
  });
  final bool loadingList, loadingDetail, saving;
  final String? error;
  final String search;
  final List<NativeContact> items;
  bool get busy => loadingList || loadingDetail || saving;

  static const _unset = Object();
  ContactsState copyWith({
    bool? loadingList,
    bool? loadingDetail,
    bool? saving,
    Object? error = _unset,
    String? search,
    List<NativeContact>? items,
  }) => ContactsState(
    loadingList: loadingList ?? this.loadingList,
    loadingDetail: loadingDetail ?? this.loadingDetail,
    saving: saving ?? this.saving,
    error: identical(error, _unset) ? this.error : error as String?,
    search: search ?? this.search,
    items: items ?? this.items,
  );
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, ContactsState>((ref) {
      final ctl = ContactsController(ref);
      Future.microtask(ctl.refresh);
      return ctl;
    });

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._ref) : super(const ContactsState());
  final Ref _ref;
  Timer? _debounce;
  int _sequence = 0;

  @override
  void dispose() {
    _sequence++;
    _debounce?.cancel();
    super.dispose();
  }

  void setSearch(String value) {
    if (!mounted) return;
    state = state.copyWith(search: value, error: null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final seq = ++_sequence;
    state = state.copyWith(loadingList: true, error: null);
    try {
      final svc = await _ref.read(nativeContactsServiceProvider.future);
      // Backend currently has pagination only. Searching this fetched page is
      // local filtering, NOT a complete global contact directory search.
      final all = await svc.list(page: 1, perPage: 50);
      final q = state.search.trim().toLowerCase();
      final items = q.isEmpty
          ? all
          : all
                .where(
                  (c) =>
                      c.displayName.toLowerCase().contains(q) ||
                      c.id.toLowerCase().contains(q) ||
                      (c.phone ?? '').toLowerCase().contains(q) ||
                      (c.email ?? '').toLowerCase().contains(q),
                )
                .toList();
      if (!mounted || seq != _sequence) return;
      state = state.copyWith(loadingList: false, items: items);
    } catch (error) {
      if (!mounted || seq != _sequence) return;
      state = state.copyWith(loadingList: false, error: '$error');
    }
  }

  Future<void> _write(
    Future<void> Function(NativeContactsService) action,
  ) async {
    if (!mounted) return;
    state = state.copyWith(saving: true, error: null);
    try {
      final svc = await _ref.read(nativeContactsServiceProvider.future);
      await action(svc);
      if (!mounted) return;
      state = state.copyWith(saving: false);
      await refresh();
    } catch (error) {
      if (mounted) state = state.copyWith(saving: false, error: '$error');
      rethrow;
    }
  }

  Future<void> create(Map<String, Object?> draft) => _write((svc) async {
    await svc.create(draft);
  });
  Future<void> update(String contactId, Map<String, Object?> patch) =>
      _write((svc) async {
        await svc.update(contactId, patch);
      });
  Future<void> removeFromApp(String contactId) =>
      _write((svc) => svc.removeFromApp(contactId));
  Future<void> delete(String contactId) => removeFromApp(contactId);

  Future<void> openCreateFlow(BuildContext context) => _openFlow(context);
  Future<void> openExistingFlow(BuildContext context, NativeContact contact) =>
      _openFlow(context, initial: contact);

  Future<void> _openFlow(BuildContext context, {NativeContact? initial}) async {
    final svc = await _ref.read(nativeContactsServiceProvider.future);
    final detailed = initial == null ? null : await svc.get(initial.id);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<ContactSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ContactEditorSheet(initial: detailed),
    );
    if (result == null || !context.mounted) return;
    try {
      await result.when<Future<void>>(
        saveRequested: (draft) =>
            initial == null ? create(draft) : update(initial.id, draft),
        deleteRequested: (id) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Remove from this app?'),
              content: const Text(
                'The canonical Native Contact and memberships in other apps will remain.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true) await removeFromApp(id);
        },
      );
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact updated')));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact operation failed: $error')),
        );
    }
  }
}

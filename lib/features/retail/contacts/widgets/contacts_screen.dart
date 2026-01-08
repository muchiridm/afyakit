// lib/features/retail/contacts/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/contacts_controller.dart';
import '../../contacts/models/zoho_contact.dart'; // ✅ adjust path if needed

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final ctl = ref.read(contactsControllerProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(state, ctl),
      floatingActionButton: _buildFab(state, ctl, context),
      body: _buildBody(context, state, ctl),
    );
  }

  AppBar _buildAppBar(ContactsState state, ContactsController ctl) {
    return AppBar(
      title: const Text('Contacts'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.loading ? null : () => ctl.refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildFab(
    ContactsState state,
    ContactsController ctl,
    BuildContext context,
  ) {
    return FloatingActionButton(
      onPressed: state.saving ? null : () => ctl.openCreateFlow(context),
      child: const Icon(Icons.add),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ContactsState state,
    ContactsController ctl,
  ) {
    return Column(
      children: [
        _buildSearchBar(state, ctl),
        if (state.error != null) _buildErrorBanner(context, state, ctl),
        Expanded(child: _buildList(context, state, ctl)),
        if (state.saving) const LinearProgressIndicator(minHeight: 3),
      ],
    );
  }

  Widget _buildSearchBar(ContactsState state, ContactsController ctl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search contacts…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: state.search.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    ctl.setSearch('');
                    ctl.refresh();
                  },
                  icon: const Icon(Icons.clear),
                ),
        ),
        onChanged: ctl.setSearch,
        onSubmitted: (_) => ctl.refresh(),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ContactsState state,
    ContactsController ctl,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Retry',
                onPressed: () => ctl.refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ContactsState state,
    ContactsController ctl,
  ) {
    return RefreshIndicator(
      onRefresh: () => ctl.refresh(),
      child: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = state.items[i];
                return _buildContactTile(context, state, ctl, c);
              },
            ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    ContactsState state,
    ContactsController ctl,
    ZohoContact c,
  ) {
    final subtitle = _subtitleFrom(c);

    return ListTile(
      onTap: state.saving ? null : () => ctl.openExistingFlow(context, c),
      title: Text(c.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      leading: CircleAvatar(child: Text(_initials(c.displayName))),
    );
  }

  String _subtitleFrom(ZohoContact c) {
    final person = (c.personName ?? '').trim();
    final company = (c.companyName ?? '').trim();

    if (person.isEmpty && company.isEmpty) return '';
    if (person.isEmpty) return company;
    if (company.isEmpty) return person;
    return '$person • $company';
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }
}

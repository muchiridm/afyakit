// lib/features/retail/contacts/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/contacts_controller.dart';
import '../../contacts/models/zoho_contact.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final ctl = ref.read(contactsControllerProvider.notifier);

    final loadingAny = state.loadingList || state.loadingDetail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.saving ? null : () => ctl.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.saving ? null : () => ctl.openCreateFlow(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ctl.refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SearchBar(
                    value: state.search,
                    enabled: !state.saving,
                    loading:
                        state.loadingList, // only list search shows spinner
                    onChanged: ctl.setSearch,
                    onClear: () => ctl.setSearch(''),
                    onSubmit: () => ctl.refresh(),
                  ),
                ),

                if (state.error != null)
                  SliverToBoxAdapter(
                    child: _ErrorBanner(
                      message: state.error!,
                      onRetry: () => ctl.refresh(),
                    ),
                  ),

                _buildSliverBody(context, state, ctl),

                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          ),

          // subtle top loading line while keeping list visible
          if (loadingAny) const LinearProgressIndicator(minHeight: 2),

          // saving indicator at bottom
          if (state.saving)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverBody(
    BuildContext context,
    ContactsState state,
    ContactsController ctl,
  ) {
    if (state.items.isEmpty && state.loadingList) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty) {
      final hasQuery = state.search.trim().isNotEmpty;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          title: hasQuery ? 'No results' : 'No contacts yet',
          subtitle: hasQuery
              ? 'Try a different search.'
              : 'Create your first contact to start quoting in Zoho.',
          actionLabel: hasQuery ? 'Clear search' : 'Create contact',
          onAction: () {
            if (hasQuery) {
              ctl.setSearch('');
              ctl.refresh();
            } else {
              ctl.openCreateFlow(context);
            }
          },
        ),
      );
    }

    return SliverList.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = state.items[i];
        return _ContactTile(
          contact: c,
          enabled: !state.saving,
          onTap: () => ctl.openExistingFlow(context, c),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onChanged,
    required this.onClear,
    required this.onSubmit,
  });

  final String value;
  final bool enabled;
  final bool loading;
  final void Function(String) onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        enabled: enabled,
        decoration: InputDecoration(
          hintText: 'Search contacts…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.trim().isEmpty
              ? (loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.clear),
                ),
        ),
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              IconButton(
                tooltip: 'Retry',
                onPressed: onRetry,
                icon: Icon(Icons.refresh, color: scheme.onErrorContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_alt_outlined, size: 44),
              const SizedBox(height: 12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.enabled,
    required this.onTap,
  });

  final ZohoContact contact;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = contact.displayName.trim();
    final subtitle = _subtitleFrom(contact);

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: CircleAvatar(child: Text(_initials(title))),
      title: Text(title.isEmpty ? 'Contact' : title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  String _subtitleFrom(ZohoContact c) {
    final display = c.displayName.trim();

    final person = c.personContact?.personName.trim() ?? '';
    final company = (c.companyName ?? '').trim();

    final phone = c.bestPhone.trim();
    final email = (c.personContact?.email ?? '').trim();

    final parts = <String>[];

    if (person.isNotEmpty && person != display) parts.add(person);
    if (company.isNotEmpty && company != display) parts.add(company);

    if (phone.isNotEmpty) {
      parts.add(phone);
    } else if (email.isNotEmpty) {
      parts.add(email);
    }

    return parts.take(2).join(' • ');
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

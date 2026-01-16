// lib/features/retail/contacts/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import '../controllers/contacts_controller.dart';
import '../../contacts/models/zoho_contact.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final ctl = ref.read(contactsControllerProvider.notifier);

    final loadingAny = state.loadingList || state.loadingDetail;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.saving ? null : () => ctl.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      fab: FloatingActionButton.extended(
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
                // ── Search
                SliverToBoxAdapter(
                  child: AppCard(
                    title: 'Search',
                    icon: Icons.search,
                    child: _SearchBar(
                      value: state.search,
                      enabled: !state.saving,
                      loading: state.loadingList,
                      onChanged: ctl.setSearch,
                      onClear: () => ctl.setSearch(''),
                      onSubmit: () => ctl.refresh(),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppShape.gap12),
                ),

                // ── Error banner
                if (state.error != null)
                  SliverToBoxAdapter(
                    child: _ErrorBanner(
                      message: state.error!,
                      onRetry: () => ctl.refresh(),
                    ),
                  ),

                if (state.error != null)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppShape.gap12),
                  ),

                // ── Main list / empty states
                _buildSliverBody(context, state, ctl),

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),

          if (loadingAny) const LinearProgressIndicator(minHeight: 2),

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
    // First load skeleton
    if (state.items.isEmpty && state.loadingList) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Empty state
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

    // Contacts list — Home-style: Card container + Tile rows
    return SliverToBoxAdapter(
      child: AppCard(
        title: 'Contacts',
        icon: Icons.people_alt_outlined,
        child: Column(
          children: [
            for (int i = 0; i < state.items.length; i++) ...[
              AppTile(
                child: _ContactTile(
                  contact: state.items[i],
                  enabled: !state.saving,
                  onTap: () => ctl.openExistingFlow(context, state.items[i]),
                ),
              ),
              if (i != state.items.length - 1)
                const SizedBox(height: AppShape.gap10),
            ],
          ],
        ),
      ),
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
    final trimmed = value.trim();

    return TextField(
      enabled: enabled,
      decoration: InputDecoration(
        hintText: 'Search contacts…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: trimmed.isEmpty
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
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppTile(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: AppShape.gap10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: scheme.error),
          ),
        ],
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
              const SizedBox(height: AppShape.gap12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap16),
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
      dense: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: EdgeInsets.zero, // AppTile already pads
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

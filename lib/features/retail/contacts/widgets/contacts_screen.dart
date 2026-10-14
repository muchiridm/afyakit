// lib/features/records/zoho_contacts/widgets/contacts_screen.dart
// Native Contacts registry screen; retained at its current path until navigation is migrated.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/native_contacts/models/native_contact.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_empty_state.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import '../controllers/contacts_controller.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  static const double _contentMaxW = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final ctl = ref.read(contactsControllerProvider.notifier);
    final loadingAny = state.loadingList || state.loadingDetail;

    return AppPage(
      scrollable: false,
      maxWidth: _contentMaxW,
      title: 'Contacts',
      showBack: true,
      actions: [
        _CountChip(
          count: state.items.length,
          loading: state.loadingList,
          hasSearch: state.search.trim().isNotEmpty,
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.saving ? null : ctl.refresh,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: state.saving ? null : () => ctl.openCreateFlow(context),
            icon: const Icon(Icons.add),
            label: const Text('Add contact'),
          ),
        ),
      ],
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: ctl.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AppCard(
                    title: 'Search loaded contacts',
                    icon: Icons.search,
                    child: _SearchBar(
                      value: state.search,
                      enabled: !state.saving,
                      loading: state.loadingList,
                      onChanged: ctl.setSearch,
                      onClear: () => ctl.setSearch(''),
                      onSubmit: ctl.refresh,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppShape.gap12),
                ),
                if (state.error != null) ...[
                  SliverToBoxAdapter(
                    child: _ErrorBanner(
                      message: state.error!,
                      onRetry: ctl.refresh,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppShape.gap12),
                  ),
                ],
                _buildSliverBody(context, state, ctl),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppShape.gap16),
                ),
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
    final hasQuery = state.search.trim().isNotEmpty;

    if (state.items.isEmpty && state.loadingList) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.people_alt_outlined,
          title: hasQuery ? 'No matches in loaded contacts' : 'No contacts',
          subtitle: hasQuery
              ? 'Try another search. Search is limited to contacts already fetched.'
              : 'No contacts were returned for this application.',
          actionLabel: hasQuery ? 'Clear search' : 'Add contact',
          onAction: () {
            if (hasQuery) {
              ctl.setSearch('');
            } else {
              ctl.openCreateFlow(context);
            }
          },
        ),
      );
    }

    return SliverToBoxAdapter(
      child: AppCard(
        title: hasQuery
            ? 'Loaded matches (${state.items.length})'
            : 'Contacts (${state.items.length})',
        icon: Icons.people_alt_outlined,
        child: Column(
          children: [
            for (var i = 0; i < state.items.length; i++) ...[
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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.loading,
    required this.hasSearch,
  });

  final int count;
  final bool loading;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        hasSearch ? Icons.manage_search : Icons.people_alt_outlined,
        size: 16,
      ),
      label: Text(
        loading
            ? 'Loading…'
            : hasSearch
            ? '$count matches'
            : '$count contacts',
      ),
    ),
  );
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
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => TextField(
    enabled: enabled,
    decoration: InputDecoration(
      hintText: 'Filter loaded contacts…',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: value.trim().isNotEmpty
          ? IconButton(
              tooltip: 'Clear',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.clear),
            )
          : loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    ),
    onChanged: onChanged,
    onSubmitted: (_) => onSubmit(),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppTile(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: AppShape.gap10),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
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

  final NativeContact contact;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = contact.displayName.trim().isEmpty
        ? 'Contact'
        : contact.displayName.trim();
    final details = <String>[
      if ((contact.accountNumber ?? '').trim().isNotEmpty)
        contact.accountNumber!.trim(),
      if (contact.contactType.trim().isNotEmpty) contact.contactType.trim(),
      if ((contact.phone ?? contact.mobile ?? contact.verifiedPhone ?? '')
          .trim()
          .isNotEmpty)
        (contact.phone ?? contact.mobile ?? contact.verifiedPhone)!.trim(),
    ];

    return ListTile(
      dense: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: contact.entityType.toLowerCase() == 'company'
            ? const Icon(Icons.apartment_outlined, size: 20)
            : Text(_initials(title)),
      ),
      title: Text(title),
      subtitle: details.isEmpty ? null : Text(details.join(' • ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.isInsurancePayer)
            const Tooltip(
              message: 'Insurance payer',
              child: Icon(Icons.verified_user_outlined, size: 20),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

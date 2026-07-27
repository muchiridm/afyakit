// lib/features/retail/contacts/widgets/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_empty_state.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import '../controllers/contacts_controller.dart';
import '../models/zoho_contact.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  static const double _contentMaxW = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final ctl = ref.read(contactsControllerProvider.notifier);

    final loadingAny = state.loadingList || state.loadingDetail;
    final count = state.items.length;

    return AppPage(
      scrollable: false,
      maxWidth: _contentMaxW,
      title: 'Contacts',
      showBack: true,
      actions: [
        _CountChip(
          count: count,
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
            icon: state.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Add customer'),
          ),
        ),
      ],
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ctl.refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
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
    final count = state.items.length;
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
          title: hasQuery ? 'No results' : 'No customers yet',
          subtitle: hasQuery
              ? 'Try a different search.'
              : 'Add your first customer to start creating quotes.',
          actionLabel: hasQuery ? 'Clear search' : 'Add customer',
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

    return SliverToBoxAdapter(
      child: AppCard(
        title: hasQuery ? 'Results ($count)' : 'Customers ($count)',
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
  Widget build(BuildContext context) {
    final label = loading
        ? 'Loading…'
        : hasSearch
        ? '$count found'
        : '$count customers';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          hasSearch ? Icons.manage_search : Icons.people_alt_outlined,
          size: 16,
        ),
        label: Text(label),
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
        hintText: 'Search customers…',
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
    final title = contact.title.trim().isEmpty ? 'Contact' : contact.title;
    final subtitle = contact.subtitle.trim();
    final linkedCount = contact.activeLinkedPatientCount;

    return ListTile(
      dense: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: contact.isCompanyOnly
            ? const Icon(Icons.apartment_outlined, size: 20)
            : Text(_initials(title)),
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.isVendor && !contact.isCustomer)
            const Tooltip(
              message: 'Vendor only',
              child: Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.local_shipping_outlined, size: 20),
              ),
            ),
          if (contact.isInsurancePayer)
            const Tooltip(
              message: 'Insurance payer',
              child: Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.verified_user_outlined, size: 20),
              ),
            ),
          if (linkedCount > 0)
            Tooltip(
              message: linkedCount == 1
                  ? '1 linked patient'
                  : '$linkedCount linked patients',
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.personal_injury_outlined, size: 16),
                label: Text('$linkedCount'),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
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

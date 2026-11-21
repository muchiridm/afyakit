// Zoho accounts screen; configured and unconfigured states.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import '../controllers/zoho_accounts_controller.dart';
import '../../shared/models/zoho_account.dart';

class ZohoAccountsScreen extends ConsumerStatefulWidget {
  const ZohoAccountsScreen({super.key});

  @override
  ConsumerState<ZohoAccountsScreen> createState() => _ZohoAccountsScreenState();
}

class _ZohoAccountsScreenState extends ConsumerState<ZohoAccountsScreen> {
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(zohoAccountsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(zohoAccountsControllerProvider);
    final controller = ref.read(zohoAccountsControllerProvider.notifier);

    return AppPage(
      title: 'Zoho Accounts',
      showBack: true,
      maxWidth: 820,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.busy ? null : controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: state.notConfigured
                ? const _ZohoNotConfiguredView()
                : _AccountsContent(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _ZohoNotConfiguredView extends StatelessWidget {
  const _ZohoNotConfiguredView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 18),
              Text(
                'Zoho Books is not configured',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Zoho Books has not been configured for this application. '
                'If you need access to accounting features, '
                'please contact your administrator.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountsContent extends StatelessWidget {
  const _AccountsContent({required this.state, required this.controller});

  final ZohoAccountsState state;
  final ZohoAccountsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ErrorBanner(message: (state.error ?? '').trim()),
        _FiltersBar(
          busy: state.busy,
          search: state.search,
          typeFilter: state.typeFilter,
          activeFilter: state.activeFilter,
          onSearch: controller.setSearch,
          onType: controller.setTypeFilter,
          onActive: controller.setActiveFilter,
          onApply: () => controller.load(force: true),
          onClear: () {
            controller.clearFilters();
            controller.load(force: true);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: state.loading && state.accounts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.accounts.isEmpty
              ? Center(
                  child: Text(
                    state.error != null
                        ? 'Unable to load accounts.'
                        : 'No accounts found.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _AccountTile(account: state.accounts[i]),
                ),
        ),
      ],
    );
  }
}

class _FiltersBar extends StatefulWidget {
  const _FiltersBar({
    required this.busy,
    required this.search,
    required this.typeFilter,
    required this.activeFilter,
    required this.onSearch,
    required this.onType,
    required this.onActive,
    required this.onApply,
    required this.onClear,
  });

  final bool busy;
  final String? search;
  final String? typeFilter;
  final bool? activeFilter;
  final ValueChanged<String?> onSearch;
  final ValueChanged<String?> onType;
  final ValueChanged<bool?> onActive;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  State<_FiltersBar> createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  late final TextEditingController _searchController;
  late final TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: (widget.search ?? '').trim(),
    );
    _typeController = TextEditingController(
      text: (widget.typeFilter ?? '').trim(),
    );
  }

  @override
  void didUpdateWidget(covariant _FiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the visible filters in sync when Clear is pressed externally.
    if (widget.search != oldWidget.search &&
        (widget.search ?? '').isEmpty &&
        _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    if (widget.typeFilter != oldWidget.typeFilter &&
        (widget.typeFilter ?? '').isEmpty &&
        _typeController.text.isNotEmpty) {
      _typeController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: widget.onSearch,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _typeController,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    labelText: 'Type (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: widget.onType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              DropdownButton<bool?>(
                value: widget.activeFilter,
                onChanged: widget.busy ? null : widget.onActive,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: true, child: Text('Active')),
                  DropdownMenuItem(value: false, child: Text('Inactive')),
                ],
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: widget.busy ? null : widget.onClear,
                child: const Text('Clear'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.busy ? null : widget.onApply,
                icon: const Icon(Icons.search),
                label: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final ZohoAccount account;

  @override
  Widget build(BuildContext context) {
    final name = account.accountName.trim().isEmpty
        ? '(Unnamed)'
        : account.accountName.trim();
    final type = (account.accountType ?? '').trim();
    final code = (account.accountCode ?? '').trim();
    final currency = (account.currencyCode ?? '').trim();
    final active = account.isActive;

    final details = <String>[
      if (type.isNotEmpty) type,
      if (code.isNotEmpty) 'Code: $code',
      if (currency.isNotEmpty) currency,
      if (active != null) (active ? 'Active' : 'Inactive'),
    ];

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            const Icon(Icons.account_balance_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details.isEmpty ? account.accountId : details.join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              account.accountId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

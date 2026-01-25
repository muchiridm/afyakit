import 'package:flutter/material.dart';
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
      ref.read(zohoAccountsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(zohoAccountsControllerProvider);
    final ctl = ref.read(zohoAccountsControllerProvider.notifier);

    return AppPage(
      title: 'Zoho Accounts',
      showBack: true,
      maxWidth: 820,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: s.busy ? null : ctl.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.busy) const LinearProgressIndicator(minHeight: 2),
          _ErrorBanner(message: (s.error ?? '').trim()),
          _FiltersBar(
            busy: s.busy,
            search: s.search,
            typeFilter: s.typeFilter,
            activeFilter: s.activeFilter,
            onSearch: (v) => ctl.setSearch(v),
            onType: (v) => ctl.setTypeFilter(v),
            onActive: (v) => ctl.setActiveFilter(v),
            onApply: () => ctl.load(force: true),
            onClear: () {
              ctl.clearFilters();
              ctl.load(force: true);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: s.loading && s.accounts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : s.accounts.isEmpty
                ? Center(
                    child: Text(
                      'No accounts found.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: s.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _AccountTile(a: s.accounts[i]),
                  ),
          ),
        ],
      ),
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
  late final TextEditingController _searchCtl;
  late final TextEditingController _typeCtl;

  @override
  void initState() {
    super.initState();
    _searchCtl = TextEditingController(text: (widget.search ?? '').trim());
    _typeCtl = TextEditingController(text: (widget.typeFilter ?? '').trim());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _typeCtl.dispose();
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
                  controller: _searchCtl,
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
                  controller: _typeCtl,
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
  const _AccountTile({required this.a});

  final ZohoAccount a;

  @override
  Widget build(BuildContext context) {
    final name = a.accountName.trim().isEmpty
        ? '(Unnamed)'
        : a.accountName.trim();
    final type = (a.accountType ?? '').trim();
    final code = (a.accountCode ?? '').trim();
    final currency = (a.currencyCode ?? '').trim();
    final active = a.isActive;

    final subtitleBits = <String>[
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
                    subtitleBits.isEmpty
                        ? a.accountId
                        : subtitleBits.join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(a.accountId, style: Theme.of(context).textTheme.bodySmall),
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
        color: Colors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/catalog/medication/catalog_medication_controller.dart';
import 'package:afyakit/hq/catalog/medication/catalog_medication.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

class HqCatalogMedicationsTab extends ConsumerStatefulWidget {
  const HqCatalogMedicationsTab({super.key, this.onPick});
  final void Function(CatalogMedication med)? onPick;

  @override
  ConsumerState<HqCatalogMedicationsTab> createState() =>
      _HqCatalogMedicationsTabState();
}

class _HqCatalogMedicationsTabState
    extends ConsumerState<HqCatalogMedicationsTab> {
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Dialog actions (UI-only; delegate to controller)
  // ─────────────────────────────────────────────────────────────

  Future<void> _importByName() async {
    final v = await DialogService.prompt(
      context: context,
      title: 'Import by name',
      // (DialogService.prompt does not take hint/keyboardType by default)
      initialValue: '',
    );
    if (v == null) return;
    await ref
        .read(catalogMedicationControllerProvider.notifier)
        .importByName(v);
  }

  Future<void> _importByRxcui() async {
    final v = await DialogService.prompt(
      context: context,
      title: 'Import by RXCUI',
      initialValue: '',
    );
    if (v == null) return;
    await ref
        .read(catalogMedicationControllerProvider.notifier)
        .importByRxcui(v);
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogMedicationControllerProvider);
    final ctrl = ref.read(catalogMedicationControllerProvider.notifier);

    if (_searchCtl.text != state.search) {
      _searchCtl.value = _searchCtl.value.copyWith(text: state.search);
    }

    return Column(
      children: [
        _buildSearchAndImportRow(
          searchText: state.search,
          onChanged: ctrl.setSearch,
          onClear: () {
            _searchCtl.clear();
            ctrl.clearSearch();
          },
          onImportByName: _importByName,
          onImportByRxcui: _importByRxcui,
        ),
        _buildLimitAndRefreshRow(
          limit: state.limit,
          onLimitChanged: ctrl.setLimit,
          onRefresh: ctrl.refresh,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ctrl.refresh,
            child: _buildResults(state),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Private builders (pure rendering)
  // ─────────────────────────────────────────────────────────────

  Widget _buildSearchAndImportRow({
    required String searchText,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required VoidCallback onImportByName,
    required VoidCallback onImportByRxcui,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtl,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search catalog… (name, synonym, ATC, RXCUI)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: onClear,
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Import',
            onSelected: (v) {
              if (v == 'name') onImportByName();
              if (v == 'rxcui') onImportByRxcui();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'name',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.text_fields),
                  title: Text('Import by name'),
                ),
              ),
              PopupMenuItem(
                value: 'rxcui',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.numbers),
                  title: Text('Import by RXCUI'),
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(Icons.download),
            ),
          ),
        ].toList(),
      ),
    );
  }

  Widget _buildLimitAndRefreshRow({
    required int limit,
    required ValueChanged<int> onLimitChanged,
    required VoidCallback onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Text('Limit'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: limit,
            onChanged: (v) => v == null ? null : onLimitChanged(v),
            items: const [20, 50, 100]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(CatalogMedicationState state) {
    if (state.loading && state.items.isEmpty) return _buildLoading();
    if (state.error != null && state.items.isEmpty) {
      return _buildError(state.error!);
    }
    if (state.items.isEmpty) return _buildEmpty();
    return _buildList(state.items);
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildError(String message) => Center(child: Text('Error: $message'));

  Widget _buildEmpty() =>
      const Center(child: Text('Type to search medications'));

  Widget _buildList(List<CatalogMedication> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) =>
          _CatalogMedicationTile(med: items[i], onPick: widget.onPick),
    );
  }
}

class _CatalogMedicationTile extends StatelessWidget {
  const _CatalogMedicationTile({required this.med, this.onPick});
  final CatalogMedication med;
  final void Function(CatalogMedication med)? onPick;

  @override
  Widget build(BuildContext context) {
    final routes = med.routes.isEmpty
        ? null
        : 'Routes: ${med.routes.join(', ')}';
    final forms = med.doseForms.isEmpty
        ? null
        : 'Forms: ${med.doseForms.join(', ')}';
    final atc = med.atcCode == null
        ? null
        : 'ATC: ${med.atcCode}${med.atcName != null ? " • ${med.atcName}" : ""}';
    final rxcui = 'RXCUI: ${med.rxcui}';

    final subtitle = [
      routes,
      forms,
      atc,
      rxcui,
    ].where((s) => s != null && s.trim().isNotEmpty).join('\n');

    return ListTile(
      dense: false,
      leading: const CircleAvatar(child: Text('RX')),
      title: Text(med.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: onPick == null
          ? null
          : FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Select'),
              onPressed: () => onPick?.call(med),
            ),
      onTap: onPick == null ? null : () => onPick?.call(med),
    );
  }
}

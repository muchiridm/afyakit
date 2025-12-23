import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';
import 'preferences_matcher_controller.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

class PreferencesMatcherScreen extends ConsumerWidget {
  const PreferencesMatcherScreen({
    super.key,
    required this.type,
    required this.incomingByField,
  });

  final ItemType type;
  final Map<ItemPreferenceField, Iterable<String>> incomingByField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(
      preferencesMatcherControllerProvider((
        type: type,
        incoming: incomingByField,
      )),
    );
    final ctrl = ref.read(
      preferencesMatcherControllerProvider((
        type: type,
        incoming: incomingByField,
      )).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences Matcher')),
      body: st.model.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (_) => _buildLoaded(context, st, ctrl),
      ),
    );
  }

  // ---- UI (dumb) -------------------------------------------------------------

  Widget _buildLoaded(
    BuildContext context,
    PreferencesMatcherState st,
    PreferencesMatcherController ctrl,
  ) {
    final fields = ctrl.fields;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: fields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final field = fields[i];
                final fm = ctrl.fieldModel(field)!;

                if (fm.incoming.isEmpty) {
                  return _fieldCard(
                    context: context,
                    title: field.label,
                    child: const Text('No values detected in file.'),
                  );
                }

                return _fieldCard(
                  context: context,
                  title: field.label,
                  child: Column(
                    children: [
                      for (final raw in fm.incoming) ...[
                        _matchRow(
                          context: context,
                          incoming: raw,
                          existing: fm.existing,
                          selected: fm.selections[raw],
                          onSelect: (val) => ctrl.select(
                            field: field,
                            incoming: raw,
                            canonical: val ?? '',
                          ),
                          onCreate: () =>
                              _createFlow(context, ctrl, field, raw),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: st.isComplete && !st.isBusy
                      ? () => Navigator.pop<Map<String, Map<String, String>>>(
                          context,
                          ctrl.buildResult(), // already string-keyed
                        )
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Mapping'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cards/rows (pure UI)
  Widget _fieldCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _matchRow({
    required BuildContext context,
    required String incoming,
    required List<String> existing,
    required String? selected,
    required ValueChanged<String?> onSelect,
    required VoidCallback onCreate,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              incoming,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 10,
          child: DropdownButtonFormField<String>(
            initialValue: (selected != null && selected.isEmpty)
                ? null
                : selected,
            isExpanded: true,
            items: existing
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: onSelect,
            decoration: const InputDecoration(
              labelText: 'Select canonical',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          tooltip: 'Create & select',
        ),
      ],
    );
  }

  // Create flow; delegates to controller
  Future<void> _createFlow(
    BuildContext context,
    PreferencesMatcherController ctrl,
    ItemPreferenceField field,
    String raw,
  ) async {
    final created = await DialogService.prompt(
      context: context,
      title: 'Create new ${field.label}',
      initialValue: raw,
    );
    final v = created?.trim() ?? '';
    if (v.isEmpty) return;
    await ctrl.createAndSelect(field: field, incoming: raw, newValue: v);
  }
}

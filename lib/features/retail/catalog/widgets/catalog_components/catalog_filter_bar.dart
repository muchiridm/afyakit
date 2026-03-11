// lib/features/retail/catalog/widgets/catalog_components/catalog_filters_bar.dart

import 'package:flutter/material.dart';

class CatalogFiltersBar extends StatelessWidget {
  const CatalogFiltersBar({
    super.key,
    required this.selectedForm,
    required this.onSelectForm,
  });

  final String selectedForm;
  final ValueChanged<String> onSelectForm;

  static const _forms = <String>[
    '',
    'tablet',
    'capsule',
    'liquid',
    'injection',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = selectedForm.trim().toLowerCase();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _forms
              .map((form) {
                final selected = form.isEmpty
                    ? normalized.isEmpty
                    : normalized == form;

                return FilterChip(
                  label: Text(_labelFor(form)),
                  selected: selected,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  side: BorderSide(
                    color: selected
                        ? theme.colorScheme.primary.withOpacity(0.22)
                        : theme.dividerColor.withOpacity(0.28),
                  ),
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.65),
                  selectedColor: theme.colorScheme.primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.72),
                  ),
                  onSelected: (_) => onSelectForm(form),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  static String _labelFor(String value) {
    switch (value) {
      case '':
        return 'All';
      case 'tablet':
        return 'Tablets';
      case 'capsule':
        return 'Capsules';
      case 'liquid':
        return 'Liquids';
      case 'injection':
        return 'Injections';
      case 'other':
        return 'Other';
      default:
        return value;
    }
  }
}

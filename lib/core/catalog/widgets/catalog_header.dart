// lib/core/catalog/widgets/catalog_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/storage/tenant_logo_providers.dart';

import 'filters_chips.dart';

class CatalogHeader extends ConsumerWidget {
  final String selectedForm;
  final ValueChanged<String> onFormChanged;

  const CatalogHeader({
    super.key,
    required this.selectedForm,
    required this.onFormChanged,
  });

  static const double _bp = 820;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < _bp;

    final filters = FiltersChips(
      initialForm: selectedForm,
      onFormChanged: onFormChanged,
    );

    final logoUrl = ref.watch(tenantLogoUrlProvider);

    final Widget logo = (logoUrl == null)
        ? const SizedBox(height: 120)
        : Image.network(
            logoUrl,
            height: 120,
            fit: BoxFit.contain,
            alignment: Alignment.bottomLeft,
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.35),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 120,
                    child: Align(alignment: Alignment.bottomLeft, child: logo),
                  ),
                  const SizedBox(height: 12),
                  filters,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 260,
                    height: 120,
                    child: Align(alignment: Alignment.bottomLeft, child: logo),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: filters,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

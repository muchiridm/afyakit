// lib/core/catalog/widgets/_filters_chips.dart
import 'package:flutter/material.dart';

class FiltersChips extends StatefulWidget {
  final String initialForm;
  final ValueChanged<String> onFormChanged;

  const FiltersChips({
    super.key,
    required this.initialForm,
    required this.onFormChanged,
  });

  @override
  State<FiltersChips> createState() => _FiltersChipsState();
}

class _FiltersChipsState extends State<FiltersChips> {
  // ⬇️ slightly smaller than before
  static const double _chipHeight = 34;
  static const double _chipHPad = 14;
  static const double _chipRadius = 999;

  late String _form = widget.initialForm;

  void _set(String v) {
    setState(() => _form = v);
    widget.onFormChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    const chips = <_ChipSpec>[
      _ChipSpec('', 'All', Icons.grid_view_rounded),
      _ChipSpec('tablet', 'Tablets', Icons.table_rows_rounded),
      _ChipSpec('capsule', 'Capsules', Icons.circle_rounded),
      _ChipSpec('liquid', 'Liquids', Icons.water_drop_rounded),
      _ChipSpec('other', 'Other', Icons.category_rounded),
    ];

    return SizedBox(
      height: _chipHeight,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final c in chips) _buildChip(context, c)],
      ),
    );
  }

  Widget _buildChip(BuildContext context, _ChipSpec c) {
    final theme = Theme.of(context);
    final selected = _form == c.value || (c.value.isEmpty && _form.isEmpty);

    final bg = selected ? theme.colorScheme.primary : theme.colorScheme.surface;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _set(selected ? '' : c.value),
        borderRadius: BorderRadius.circular(_chipRadius),
        child: Container(
          height: _chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: _chipHPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_chipRadius),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : theme.dividerColor.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                c.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipSpec {
  final String value;
  final String label;
  final IconData icon;
  const _ChipSpec(this.value, this.label, this.icon);
}

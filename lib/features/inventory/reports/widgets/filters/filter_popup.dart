import 'package:flutter/material.dart';

class FilterPopup<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final Set<T> selected;
  final bool isMultiSelect;
  final ValueChanged<Set<T>> onChanged;
  final String Function(T)? labelBuilder;
  final bool showSelectAll;
  final bool enabled;

  /// Optional "All" option support
  final bool allowAllOption;
  final T? allOptionValue;
  final String? allOptionLabel;

  const FilterPopup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.isMultiSelect = false,
    this.labelBuilder,
    this.showSelectAll = false,
    this.enabled = true,
    this.allowAllOption = false,
    this.allOptionValue,
    this.allOptionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == options.length;
    final toggleLabel = allSelected ? 'Unselect All' : 'Select All';

    final List<T> menuOptions = [
      if (allowAllOption && allOptionValue != null) allOptionValue!,
      ...options,
    ];

    return SizedBox(
      height: 56,
      child: Builder(
        builder: (context) {
          return InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap:
                !enabled
                    ? null
                    : () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final box = context.findRenderObject();
                        final overlay =
                            Overlay.of(context).context.findRenderObject();

                        if (box is! RenderBox || overlay is! RenderBox) return;

                        final position = RelativeRect.fromLTRB(
                          box.localToGlobal(Offset.zero, ancestor: overlay).dx,
                          box
                              .localToGlobal(
                                box.size.bottomLeft(Offset.zero),
                                ancestor: overlay,
                              )
                              .dy,
                          double.infinity,
                          0,
                        );

                        showMenu<T>(
                          context: context,
                          position: position,
                          items: [
                            if (isMultiSelect && showSelectAll)
                              PopupMenuItem<T>(
                                value: '__TOGGLE_ALL__' as T,
                                child: Text(toggleLabel),
                              ),
                            ...menuOptions.map((opt) {
                              final labelText = _labelFor(opt);
                              return isMultiSelect
                                  ? CheckedPopupMenuItem<T>(
                                    value: opt,
                                    checked: selected.contains(opt),
                                    child: Text(labelText),
                                  )
                                  : PopupMenuItem<T>(
                                    value: opt,
                                    child: Text(labelText),
                                  );
                            }),
                          ],
                        ).then((value) {
                          if (value == null) return;

                          if (value is String && value == '__TOGGLE_ALL__') {
                            onChanged(allSelected ? {} : options.toSet());
                            return;
                          }

                          final newSet = Set<T>.from(selected);

                          if (isMultiSelect) {
                            newSet.contains(value)
                                ? newSet.remove(value)
                                : newSet.add(value);
                            onChanged(newSet);
                          } else {
                            onChanged({value});
                          }
                        });
                      });
                    },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(),
              ),
              child: Text(
                _displayLabel(menuOptions),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  String _labelFor(T value) {
    if (allowAllOption && value == allOptionValue) {
      return allOptionLabel ?? 'All';
    }
    return labelBuilder?.call(value) ?? value.toString();
  }

  String _displayLabel(List<T> menuOptions) {
    if (isMultiSelect) {
      if (selected.isEmpty) return 'Select $label';
      if (selected.length == options.length) return 'All $label Selected';
      return '${selected.length} selected';
    }

    final sel = selected.isNotEmpty ? selected.first : allOptionValue;
    return _labelFor(sel as T);
  }
}

// lib/shared/widgets/pickers/entity_picker_widgets.dart

import 'package:flutter/material.dart';

typedef PickerRefreshCallback = Future<void> Function();

class PickerHeader extends StatelessWidget {
  const PickerHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.singularLabel,
    required this.pluralLabel,
    required this.isLoading,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final int count;
  final String singularLabel;
  final String pluralLabel;
  final bool isLoading;
  final PickerRefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                count == 1
                    ? '1 $singularLabel available.'
                    : '$count $pluralLabel available.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh $pluralLabel',
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    required this.onAction,
    this.enabled = true,
    this.actionTooltip = 'Refresh',
    this.actionIcon = Icons.refresh,
    this.submitAction = false,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final PickerRefreshCallback onAction;
  final bool enabled;
  final String actionTooltip;
  final IconData actionIcon;
  final bool submitAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction:
          submitAction ? TextInputAction.search : TextInputAction.done,
      decoration: InputDecoration(
        isDense: true,
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: actionTooltip,
          onPressed: enabled ? onAction : null,
          icon: Icon(actionIcon),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onSubmitted: submitAction && enabled ? (_) => onAction() : null,
    );
  }
}

class PickerErrorText extends StatelessWidget {
  const PickerErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class PickerBody<T> extends StatelessWidget {
  const PickerBody({
    super.key,
    required this.items,
    required this.isLoading,
    required this.emptyText,
    required this.emptyIcon,
    required this.itemBuilder,
  });

  final List<T> items;
  final bool isLoading;
  final String emptyText;
  final IconData emptyIcon;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return PickerEmptyState(
        text: emptyText,
        icon: emptyIcon,
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        return itemBuilder(context, items[index]);
      },
    );
  }
}

class PickerEmptyState extends StatelessWidget {
  const PickerEmptyState({
    super.key,
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 96;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: compact
                ? Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

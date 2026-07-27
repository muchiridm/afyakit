// lib/core/home/widgets/shared/home_dashboard/home_speed_dial.dart

import 'package:flutter/material.dart';

class HomeSpeedDialAction {
  const HomeSpeedDialAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class HomeSpeedDial extends StatelessWidget {
  const HomeSpeedDial({
    super.key,
    required this.actions,
    this.tooltip = 'Quick actions',
    this.icon = Icons.add_rounded,
    this.title = 'Quick actions',
  });

  final List<HomeSpeedDialAction> actions;
  final String tooltip;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      tooltip: tooltip,
      onPressed: () => _showActions(context),
      child: Icon(icon),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<HomeSpeedDialAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _HomeQuickActionsSheet(title: title, actions: actions);
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    action.onPressed();
  }
}

class _HomeQuickActionsSheet extends StatelessWidget {
  const _HomeQuickActionsSheet({required this.title, required this.actions});

  final String title;
  final List<HomeSpeedDialAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(action.icon),
                  title: Text(
                    action.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: theme.colorScheme.surfaceContainerLow,
                  onTap: () {
                    Navigator.of(context).pop(action);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

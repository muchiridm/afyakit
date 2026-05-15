// lib/core/home/widgets/staff/staff_primary_actions.dart

import 'package:flutter/material.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class StaffPrimaryActions extends StatelessWidget {
  const StaffPrimaryActions({
    super.key,
    required this.onAddCustomer,
    required this.onAddPatient,
    required this.onRespondToChats,
    this.dense = false,
  });

  final VoidCallback onAddCustomer;
  final VoidCallback onAddPatient;
  final VoidCallback onRespondToChats;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < (dense ? 360 : 540);

        final actions = [
          _StaffPrimaryActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: dense ? 'Customer' : 'Add customer',
            filled: true,
            dense: dense,
            onTap: onAddCustomer,
          ),
          _StaffPrimaryActionButton(
            icon: Icons.personal_injury_outlined,
            label: dense ? 'Patient' : 'Add patient',
            dense: dense,
            onTap: onAddPatient,
          ),
          _StaffPrimaryActionButton(
            icon: Icons.mark_chat_unread_outlined,
            label: dense ? 'Chats' : 'Chats',
            dense: dense,
            onTap: onRespondToChats,
          ),
        ];

        if (narrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  actions[i],
                  if (i != actions.length - 1)
                    SizedBox(width: dense ? 6 : AppShape.gap8),
                ],
              ],
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              Flexible(child: actions[i]),
              if (i != actions.length - 1)
                SizedBox(width: dense ? 6 : AppShape.gap8),
            ],
          ],
        );
      },
    );
  }
}

class _StaffPrimaryActionButton extends StatelessWidget {
  const _StaffPrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dense,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final bg = filled ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = filled ? scheme.onPrimary : scheme.onSurface;
    final border = filled
        ? BorderSide.none
        : BorderSide(color: scheme.outlineVariant.withOpacity(0.75));

    return Material(
      color: bg,
      elevation: filled ? 1.2 : 0,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: dense ? 34 : 38,
          constraints: BoxConstraints(minWidth: dense ? 94 : 122),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.fromBorderSide(border),
          ),
          padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: dense ? 15 : 16, color: fg),
              SizedBox(width: dense ? 5 : 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (dense ? t.labelSmall : t.labelMedium)?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
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

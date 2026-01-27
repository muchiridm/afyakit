import 'package:flutter/material.dart';

/// Reusable status chip for invoices + quotes (list + details).
///
/// Goal: match the OLD Chip look you liked (invoice list),
/// and only add *subtle* color via text + outline (no colored fill).
class SalesDocStatusChip extends StatelessWidget {
  const SalesDocStatusChip({
    super.key,
    required this.status,
    this.visualDensity = VisualDensity.compact,
    this.forceLabel,
  });

  final String status;

  /// Keep compact by default (matches your list rows).
  final VisualDensity visualDensity;

  /// Optional override: e.g. show "editing" / "draft" in editor header.
  final String? forceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final raw = (forceLabel ?? status).trim();
    final s = status.trim().toLowerCase();
    final label = raw.isEmpty ? 'unknown' : raw;

    final tone = SalesDocStatusTone.of(s, scheme);

    // Start from ChipTheme so we keep the app's exact Material vibe.
    final baseLabelStyle =
        theme.chipTheme.labelStyle ??
        theme.textTheme.labelLarge ??
        const TextStyle();

    final BorderSide? side = tone.border == null
        ? null
        : BorderSide(color: tone.border!);

    return Chip(
      visualDensity: visualDensity,
      label: Text(label),

      // Keep it "plain" even if the theme sets filled assist chips.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,

      // Only set side when we actually want an outline.
      side: side,

      // Only tint the text; keep theme's sizing/weight exactly as-is.
      labelStyle: baseLabelStyle.copyWith(color: tone.fg),
    );
  }
}

/// Optional leading icon for list rows.
/// Goal: match your invoice list vibe: soft green circle, simple icon.
class SalesDocLeadingIcon extends StatelessWidget {
  const SalesDocLeadingIcon({
    super.key,
    required this.status,
    this.radius = 18,
  });

  final String status;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = status.trim().toLowerCase();

    // Keep this consistent like your invoice list:
    // green-ish container always, status meaning is carried by the chip.
    final bg = scheme.primaryContainer;
    final fg = scheme.onPrimaryContainer;

    final icon = SalesDocStatusX.iconFor(s);

    final iconSize = (radius * 0.95).clamp(16.0, 20.0);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Status -> colors (used by chip).
class SalesDocStatusTone {
  const SalesDocStatusTone({required this.fg, this.border});

  final Color fg;

  /// Null means: don't draw a border override (let ChipTheme decide).
  final Color? border;

  static SalesDocStatusTone of(String normalizedStatus, ColorScheme scheme) {
    final s = normalizedStatus;

    Color stroke(Color c) => c.withOpacity(0.38);

    // Paid
    if (SalesDocStatusX.isPaid(s)) {
      return SalesDocStatusTone(
        fg: scheme.tertiary,
        border: stroke(scheme.tertiary),
      );
    }

    // Partial
    if (SalesDocStatusX.isPartial(s)) {
      return SalesDocStatusTone(
        fg: scheme.primary,
        border: stroke(scheme.primary),
      );
    }

    // Overdue
    if (SalesDocStatusX.isOverdue(s)) {
      return SalesDocStatusTone(fg: scheme.error, border: stroke(scheme.error));
    }

    // Void / Cancelled
    if (SalesDocStatusX.isVoidOrCancelled(s)) {
      return SalesDocStatusTone(
        fg: scheme.onSurfaceVariant,
        border: scheme.outlineVariant,
      );
    }

    // Sent
    if (SalesDocStatusX.isSent(s)) {
      return SalesDocStatusTone(
        fg: scheme.primary,
        border: stroke(scheme.primary),
      );
    }

    // Draft / Editing
    if (SalesDocStatusX.isDraftOrEditing(s)) {
      return SalesDocStatusTone(
        fg: scheme.secondary,
        border: stroke(scheme.secondary),
      );
    }

    // Open / Unpaid / Due
    if (SalesDocStatusX.isOpenLike(s)) {
      return SalesDocStatusTone(
        fg: scheme.secondary,
        border: stroke(scheme.secondary),
      );
    }

    // Fallback: keep neutral + don't force an outline.
    return SalesDocStatusTone(fg: scheme.onSurfaceVariant, border: null);
  }
}

class SalesDocStatusX {
  static IconData iconFor(String s) {
    if (isPaid(s)) return Icons.verified_outlined;
    if (isPartial(s)) return Icons.payments_outlined;
    if (isOverdue(s)) return Icons.warning_amber_outlined;
    if (isSent(s)) return Icons.send_outlined;
    if (isDraftOrEditing(s)) return Icons.edit_note_outlined;
    if (isVoidOrCancelled(s)) return Icons.block_outlined;
    return Icons.receipt_outlined;
  }

  static bool isPaid(String s) => s.contains('paid') && !s.contains('partial');
  static bool isPartial(String s) => s.contains('partial');
  static bool isOverdue(String s) => s.contains('overdue');
  static bool isVoidOrCancelled(String s) =>
      s.contains('void') || s.contains('cancel');
  static bool isDraftOrEditing(String s) =>
      s.contains('draft') || s.contains('editing');
  static bool isSent(String s) => s.contains('sent');
  static bool isOpenLike(String s) =>
      s.contains('open') || s.contains('unpaid') || s.contains('due');
}

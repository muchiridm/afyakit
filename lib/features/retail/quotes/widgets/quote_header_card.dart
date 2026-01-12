// lib/features/retail/quotes/widgets/quote_header_card.dart

import 'package:afyakit/features/retail/quotes/extensions/quote_editor_mode_x.dart';
import 'package:flutter/material.dart';

import '../controllers/quote_editor_state.dart';

class QuoteHeaderCard extends StatelessWidget {
  const QuoteHeaderCard({
    super.key,
    required this.state,
    required this.onPickContact,
    required this.onClearContact,
    required this.onReferenceChanged,
    required this.onNotesChanged,
    required this.onSubmit,
    required this.submitLabel,
    this.disableEditing = false,
  });

  final QuoteEditorState state;

  final VoidCallback? onPickContact;
  final VoidCallback? onClearContact;

  final void Function(String)? onReferenceChanged;
  final void Function(String)? onNotesChanged;

  final VoidCallback? onSubmit;
  final String submitLabel;

  final bool disableEditing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer', style: t.titleMedium),
          const SizedBox(height: 8),
          _buildContactTile(context),

          const SizedBox(height: 12),
          _buildTotalsCard(context),

          const SizedBox(height: 12),
          _buildReferenceField(),
          const SizedBox(height: 8),
          _buildNotesField(),
          const SizedBox(height: 12),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildContactTile(BuildContext context) {
    final canPick =
        onPickContact != null && !state.savingQuote && !state.loadingQuote;
    final canClear =
        onClearContact != null && state.draft.contact != null && canPick;

    final title = state.customerLabel;
    final subtitle = _customerSubtitle().trim();

    return Material(
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        enabled: canPick,
        leading: const Icon(Icons.person_outline),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: canPick
            ? (state.draft.contact == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: canClear ? onClearContact : null,
                      icon: const Icon(Icons.clear),
                    ))
            : null,
        onTap: canPick ? onPickContact : null,
      ),
    );
  }

  Widget _buildTotalsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final lines = state.draft.lines;
    final lineCount = lines.length;

    final currency = (state.currencyCode ?? '').trim().isNotEmpty
        ? (state.currencyCode ?? '').trim()
        : 'KES';

    final total = state.draft.total;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Items',
                value: lineCount.toString(),
                icon: Icons.shopping_basket_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                label: 'Total',
                value: _money(total, currency: currency),
                icon: Icons.payments_outlined,
                valueStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _customerSubtitle() {
    // Prefer full ZohoContact info (create mode after pick)
    final c = state.draft.contact;
    if (c != null) {
      final parts =
          <String?>[
                c.personContact?.personName,
                c.companyName,
                c.bestPhone,
                c.personContact?.email,
              ]
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      return parts.take(2).join(' • ');
    }

    // Preview/edit: show lightweight backend context
    final parts = <String>[];
    final id = (state.customerId ?? '').trim();
    final cur = (state.currencyCode ?? '').trim();

    if (id.isNotEmpty) parts.add('Zoho: $id');
    if (cur.isNotEmpty) parts.add(cur);

    // Create mode with no contact picked
    if (parts.isEmpty && state.mode.canPickContact) {
      return 'Pick a contact to create the quote';
    }

    return parts.take(2).join(' • ');
  }

  Widget _buildReferenceField() {
    final enabled =
        !disableEditing &&
        !state.savingQuote &&
        !state.loadingQuote &&
        onReferenceChanged != null;

    return TextFormField(
      enabled: enabled,
      initialValue: (state.draft.reference ?? '').trim(),
      decoration: const InputDecoration(
        labelText: 'Reference (optional)',
        hintText: 'e.g. PO-123 / Clinic Visit / WhatsApp Order',
      ),
      onChanged: onReferenceChanged,
    );
  }

  Widget _buildNotesField() {
    final enabled =
        !disableEditing &&
        !state.savingQuote &&
        !state.loadingQuote &&
        onNotesChanged != null;

    return TextFormField(
      enabled: enabled,
      initialValue: (state.draft.customerNotes ?? ''),
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Notes (optional)',
        hintText: 'Customer notes to show on the quote',
      ),
      onChanged: onNotesChanged,
    );
  }

  Widget _buildSubmitButton() {
    final disabled =
        state.savingQuote || state.loadingQuote || onSubmit == null;

    return FilledButton.icon(
      onPressed: disabled ? null : onSubmit,
      icon: const Icon(Icons.receipt_long),
      label: Text(submitLabel),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData icon;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (t.titleMedium ?? const TextStyle()).merge(
                  valueStyle ?? const TextStyle(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lightweight money formatting with thousands separators (no intl).
String _money(num v, {required String currency}) {
  // Keep 2 decimals only if needed
  final hasDecimals = (v % 1) != 0;
  final s = hasDecimals ? v.toStringAsFixed(2) : v.round().toString();

  final parts = s.split('.');
  final whole = parts[0];
  final frac = parts.length > 1 ? parts[1] : null;

  final buf = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    final left = whole.length - i;
    buf.write(whole[i]);
    if (left > 1 && left % 3 == 1) buf.write(',');
  }

  return frac == null
      ? '$currency ${buf.toString()}'
      : '$currency ${buf.toString()}.$frac';
}

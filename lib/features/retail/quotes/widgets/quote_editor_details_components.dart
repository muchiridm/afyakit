// lib/features/retail/quotes/widgets/quote_editor_details_components.dart

import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/date_pill.dart';
import 'package:flutter/material.dart';

class QuoteDetailsQuestionSection extends StatelessWidget {
  const QuoteDetailsQuestionSection({
    super.key,
    required this.number,
    required this.complete,
    required this.title,
    required this.child,
    this.subtitle,
    this.requiredQuestion = true,
  });

  final int number;
  final bool complete;
  final bool requiredQuestion;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final bool requiredIncomplete = requiredQuestion && !complete;

    final Color markerColor = complete
        ? Colors.green
        : requiredIncomplete
        ? scheme.error
        : scheme.surfaceContainerHighest;

    final Color markerTextColor = complete
        ? Colors.white
        : requiredIncomplete
        ? scheme.onError
        : scheme.onSurfaceVariant;

    final Color? headingColor = requiredIncomplete ? scheme.error : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: complete
                    ? Icon(
                        Icons.check,
                        key: ValueKey<String>('done-$number'),
                        size: 18,
                        color: markerTextColor,
                      )
                    : Text(
                        '$number',
                        key: ValueKey<String>('number-$number'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: markerTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: headingColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: headingColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.only(left: 40), child: child),
      ],
    );
  }
}

class QuoteDetailsCompanyTile extends StatelessWidget {
  const QuoteDetailsCompanyTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoTile(
      icon: Icons.business_outlined,
      title: 'Company or organisation',
      subtitle:
          'The selected customer is billed directly. Patient, insurance and prescription details are not required.',
    );
  }
}

class QuoteDetailsPickupTile extends StatelessWidget {
  const QuoteDetailsPickupTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoTile(
      icon: Icons.storefront_outlined,
      title: 'Pickup',
      subtitle: 'No delivery location is required.',
    );
  }
}

class QuoteDetailsDeliveryLocationTile extends StatelessWidget {
  const QuoteDetailsDeliveryLocationTile({
    super.key,
    required this.address,
    required this.onTap,
    required this.onClear,
  });

  final SalesDocumentAddress? address;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final String title =
        _clean(address?.shortDisplay) ??
        _clean(address?.singleLine) ??
        'Select delivery location';

    final String subtitle = _join(<String?>[
      address?.area,
      address?.city,
      address?.county,
    ]);

    return _SelectionTile(
      icon: Icons.location_on_outlined,
      title: title,
      subtitle: subtitle.isEmpty
          ? 'Choose a location so delivery can be included in the quote.'
          : subtitle,
      onTap: onTap,
      onClear: onClear,
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (onClear != null)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          child: _TileContent(icon: icon, title: title, subtitle: subtitle),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      child: _TileContent(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class QuoteDetailsDateFields extends StatelessWidget {
  const QuoteDetailsDateFields({
    super.key,
    required this.quoteDate,
    required this.expiryDate,
    required this.onPickQuoteDate,
    required this.onClearQuoteDate,
    required this.onPickExpiryDate,
    required this.onClearExpiryDate,
  });

  final DateTime? quoteDate;
  final DateTime? expiryDate;
  final Future<void> Function() onPickQuoteDate;
  final VoidCallback onClearQuoteDate;
  final Future<void> Function() onPickExpiryDate;
  final VoidCallback onClearExpiryDate;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SalesDocDatePill(
              label: 'Date *',
              icon: Icons.event_outlined,
              date: quoteDate,
              enabled: true,
              onPick: onPickQuoteDate,
              onClear: onClearQuoteDate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SalesDocDatePill(
              label: 'Expiry',
              icon: Icons.timelapse_outlined,
              date: expiryDate,
              enabled: true,
              onPick: onPickExpiryDate,
              onClear: onClearExpiryDate,
            ),
          ),
        ],
      ),
    );
  }
}

class QuoteDetailsSheetFooter extends StatelessWidget {
  const QuoteDetailsSheetFooter({
    super.key,
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: const Icon(Icons.check),
              label: const Text('Use details'),
            ),
          ),
        ],
      ),
    );
  }
}

String? _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String _join(List<String?> values, {String separator = ' • '}) {
  return values
      .map((String? value) => (value ?? '').trim())
      .where((String value) => value.isNotEmpty)
      .join(separator);
}

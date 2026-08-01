// lib/features/retail/quotes/widgets/quote_details_summary.dart

import 'package:afyakit/features/retail/quotes/controllers/states/quote_meta_state.dart';
import 'package:flutter/material.dart';

class QuoteDetailsSummary extends StatelessWidget {
  const QuoteDetailsSummary({
    super.key,
    required this.meta,
    required this.busy,
    required this.onTap,
  });

  final QuoteMetaState meta;
  final bool busy;
  final VoidCallback onTap;

  bool get _patientComplete {
    return meta.isCompany || meta.hasPatientContext;
  }

  bool get _insuranceComplete {
    if (meta.isCompany || !meta.isInsurancePayment) return true;

    return _clean(meta.resolvedMembershipId) != null;
  }

  bool get _prescriptionComplete {
    if (meta.isCompany || !meta.isInsurancePayment) return true;

    return _clean(meta.resolvedPrescriptionId) != null;
  }

  bool get _fulfilmentComplete {
    if (meta.fulfilmentMethod.isPickup) return true;

    return meta.hasDeliveryAddress;
  }

  bool get _detailsComplete {
    return _patientComplete &&
        _insuranceComplete &&
        _prescriptionComplete &&
        _fulfilmentComplete;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final bool complete = _detailsComplete;

    final Color accentColor = complete ? colors.onSurfaceVariant : colors.error;

    final String title = complete
        ? 'Quote details'
        : 'Quote details incomplete';

    final String purchaseSummary = _purchaseSummary(meta);
    final String fulfilmentSummary = _fulfilmentSummary(meta);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: complete
            ? colors.surface
            : colors.errorContainer.withValues(alpha: 0.18),
        border: Border(
          bottom: BorderSide(
            color: complete ? colors.outlineVariant : colors.error,
          ),
        ),
      ),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: <Widget>[
              Icon(
                complete ? Icons.tune_outlined : Icons.error_outline,
                size: 20,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: complete ? null : colors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      purchaseSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: complete ? null : colors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fulfilmentSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: complete
                            ? colors.onSurfaceVariant
                            : colors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: busy
                    ? colors.onSurface.withValues(alpha: 0.38)
                    : accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _purchaseSummary(QuoteMetaState meta) {
    if (meta.isCompany) {
      return 'Company · Direct pay';
    }

    final List<String> parts = <String>[
      'Private use',
      meta.isInsurancePayment ? 'Insurance' : 'Direct pay',
    ];

    if (meta.hasPatientContext) {
      parts.add(meta.patientLabel);
    } else {
      parts.add('Patient required');
    }

    if (meta.isInsurancePayment) {
      if (_clean(meta.resolvedMembershipId) == null) {
        parts.add('Membership required');
      }

      if (_clean(meta.resolvedPrescriptionId) == null) {
        parts.add('Prescription required');
      }
    }

    return parts.join(' · ');
  }

  String _fulfilmentSummary(QuoteMetaState meta) {
    if (meta.fulfilmentMethod.isPickup) {
      return 'Pickup';
    }

    if (!meta.hasDeliveryAddress) {
      return 'Delivery · Location required';
    }

    final String location =
        _clean(meta.deliveryAddress?.shortDisplay) ??
        _clean(meta.deliveryAddress?.singleLine) ??
        _join(<String?>[
          meta.deliveryAddress?.area,
          meta.deliveryAddress?.city,
          meta.deliveryAddress?.county,
        ]);

    return location.isEmpty ? 'Delivery' : 'Delivery · $location';
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static String _join(List<String?> parts) {
    return parts
        .map((String? value) => (value ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .join(', ');
  }
}

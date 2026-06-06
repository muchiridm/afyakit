// lib/features/clinical/prescriptions/widgets/prescription_picker.dart

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:flutter/material.dart';

class PrescriptionPickerCard extends StatelessWidget {
  const PrescriptionPickerCard({
    super.key,
    required this.patientId,
    required this.prescriptions,
    required this.selectedPrescriptionId,
    required this.busy,
    required this.onChanged,
    this.error,
    this.requiredForClaim = false,
    this.onRefresh,
    this.onUpload,
  });

  final String? patientId;
  final List<Prescription> prescriptions;
  final String? selectedPrescriptionId;
  final bool busy;
  final String? error;
  final bool requiredForClaim;
  final ValueChanged<Prescription?> onChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onUpload;

  bool get _hasPatient => (patientId ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<Prescription> active = prescriptions
        .where((Prescription p) => p.isActive)
        .toList(growable: false);

    // Important:
    // Do NOT hide uploaded / pending-review prescriptions in insurance mode.
    // Newly uploaded prescriptions are usually not verified yet, but staff still
    // need to see and select them. Verification/submission rules should be
    // handled by workflow validation, not by making the upload disappear.
    final List<Prescription> selectable = active;

    final String? selected =
        selectable.any(
          (Prescription p) => p.prescriptionId == selectedPrescriptionId,
        )
        ? selectedPrescriptionId
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(child: Icon(Icons.description_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderText(
                    hasPatient: _hasPatient,
                    requiredForClaim: requiredForClaim,
                    count: selectable.length,
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: 'Refresh prescriptions',
                    onPressed: busy || !_hasPatient ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                if (onUpload != null)
                  FilledButton.icon(
                    onPressed: busy || !_hasPatient ? null : onUpload,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasPatient)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Prescription',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  'Select a patient first',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
              )
            else if (busy)
              const InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Prescription',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading prescriptions…'),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: requiredForClaim
                      ? 'Prescription for claim'
                      : 'Prescription',
                  border: const OutlineInputBorder(),
                  errorText: error,
                  helperText: _helperText(activeCount: active.length),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('No prescription selected'),
                  ),
                  ...selectable.map((Prescription p) {
                    return DropdownMenuItem<String>(
                      value: p.prescriptionId,
                      child: Text(_label(p), overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (String? value) {
                  final String id = (value ?? '').trim();

                  if (id.isEmpty) {
                    onChanged(null);
                    return;
                  }

                  final Prescription? picked = _findById(selectable, id);
                  onChanged(picked);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _helperText({required int activeCount}) {
    if (!_hasPatient) return 'Select a patient first';

    if (activeCount == 0) return 'No active prescriptions found';

    if (requiredForClaim) {
      return 'Required for insurance claims. Prefer a verified prescription.';
    }

    return 'Optional for direct-pay quotes';
  }

  static Prescription? _findById(List<Prescription> items, String id) {
    for (final Prescription p in items) {
      if (p.prescriptionId == id) return p;
    }

    return null;
  }

  static String _label(Prescription p) {
    final List<String> parts = <String>[
      p.fileName.trim().isNotEmpty ? p.fileName.trim() : p.prescriptionId,
      if ((p.prescribedOn ?? '').trim().isNotEmpty) p.prescribedOn!.trim(),
      p.status.label,
    ];

    return parts.join(' • ');
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.hasPatient,
    required this.requiredForClaim,
    required this.count,
  });

  final bool hasPatient;
  final bool requiredForClaim;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          requiredForClaim ? 'Prescription required' : 'Prescription',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          !hasPatient
              ? 'Choose a patient before selecting a prescription.'
              : count == 1
              ? '1 prescription available.'
              : '$count prescriptions available.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

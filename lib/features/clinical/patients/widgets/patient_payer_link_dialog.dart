// lib/features/clinical/patients/widgets/patient_payer_link_dialog.dart

import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';
import 'package:flutter/material.dart';

class PatientPayerLinkDialog {
  const PatientPayerLinkDialog._();

  static const EdgeInsets _scrollPadding = EdgeInsets.only(
    top: 14,
    right: 8,
    bottom: 8,
  );

  static double _height(
    BuildContext context, {
    required double fraction,
    required double min,
    required double max,
  }) {
    final value = MediaQuery.of(context).size.height * fraction;
    return value.clamp(min, max).toDouble();
  }

  static String? _cleanNullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<PatientLinkRequestCreateInput?> showRequest({
    required BuildContext context,
    required PatientProfile patient,
  }) async {
    final relationship = ValueNotifier<PatientContactRelationship>(
      PatientContactRelationship.insurance,
    );

    final gender = ValueNotifier<PatientGender>(
      patient.gender ?? PatientGender.unknown,
    );

    final payerNameCtl = TextEditingController();
    final accountNumberCtl = TextEditingController();
    final payerPhoneCtl = TextEditingController();
    final payerEmailCtl = TextEditingController();
    final reasonCtl = TextEditingController();

    final fullNameCtl = TextEditingController(text: patient.fullName);
    final dobCtl = TextEditingController(text: patient.dob ?? '');
    final phoneCtl = TextEditingController(text: patient.phone ?? '');
    final emailCtl = TextEditingController(text: patient.email ?? '');
    final nationalIdCtl = TextEditingController(text: patient.nationalId ?? '');
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<PatientLinkRequestCreateInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Request payer link'),
          content: SizedBox(
            width: 760,
            height: _height(context, fraction: 0.72, min: 420, max: 680),
            child: Form(
              key: formKey,
              child: ValueListenableBuilder<PatientContactRelationship>(
                valueListenable: relationship,
                builder: (_, rel, __) {
                  return SingleChildScrollView(
                    padding: _scrollPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: 260,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'DawaPap patient ID',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: SelectableText(patient.patientId),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child:
                                  DropdownButtonFormField<
                                    PatientContactRelationship
                                  >(
                                    initialValue: rel,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Payer relationship',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      helperText: 'Requires staff approval.',
                                    ),
                                    items: PatientProfilesLabels
                                        .payerRequestRelationships
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(
                                              PatientProfilesLabels.relationship(
                                                value,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    selectedItemBuilder: (context) {
                                      return PatientProfilesLabels
                                          .payerRequestRelationships
                                          .map(
                                            (value) => Text(
                                              PatientProfilesLabels.relationship(
                                                value,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )
                                          .toList(growable: false);
                                    },
                                    onChanged: (value) {
                                      if (value != null) {
                                        relationship.value = value;
                                      }
                                    },
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Tell us who should be linked as an insurance provider or payer. Staff will review the request before any billing-related link is applied.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: 330,
                              child: TextFormField(
                                controller: payerNameCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Insurance / payer name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: TextFormField(
                                controller: accountNumberCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Account/member number',
                                  hintText: 'Optional',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: payerPhoneCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Payer/contact phone',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 280,
                              child: TextFormField(
                                controller: payerEmailCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Payer/contact email',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 720,
                              child: TextFormField(
                                controller: reasonCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Reason / notes',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                minLines: 2,
                                maxLines: 4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Confirm at least 3 patient identifiers. This protects patients from being linked to the wrong payer/contact.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: 330,
                              child: TextFormField(
                                controller: fullNameCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm full name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: ValueListenableBuilder<PatientGender>(
                                valueListenable: gender,
                                builder: (_, value, __) {
                                  return DropdownButtonFormField<PatientGender>(
                                    initialValue: value,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm gender',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: PatientGender.values
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(
                                              PatientProfilesLabels.gender(g),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (next) {
                                      if (next != null) gender.value = next;
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: dobCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm DOB',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: phoneCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm phone',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 280,
                              child: TextFormField(
                                controller: emailCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm email',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: nationalIdCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm national ID',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  PatientLinkRequestCreateInput(
                    relationship: relationship.value,
                    targetContactDisplayName: payerNameCtl.text.trim(),
                    targetAccountNumber: accountNumberCtl.text.trim(),
                    targetPhone: payerPhoneCtl.text.trim(),
                    targetEmail: payerEmailCtl.text.trim(),
                    reason: reasonCtl.text.trim(),
                    confirmFullName: fullNameCtl.text.trim(),
                    confirmGender: gender.value,
                    confirmDob: dobCtl.text.trim(),
                    confirmPhone: phoneCtl.text.trim(),
                    confirmEmail: emailCtl.text.trim(),
                    confirmNationalId: nationalIdCtl.text.trim(),
                  ),
                );
              },
              child: const Text('Submit request'),
            ),
          ],
        ),
      );
    } finally {
      relationship.dispose();
      gender.dispose();

      payerNameCtl.dispose();
      accountNumberCtl.dispose();
      payerPhoneCtl.dispose();
      payerEmailCtl.dispose();
      reasonCtl.dispose();

      fullNameCtl.dispose();
      dobCtl.dispose();
      phoneCtl.dispose();
      emailCtl.dispose();
      nationalIdCtl.dispose();
    }
  }

  static Future<PatientLinkRequestApproveInput?> showApprove({
    required BuildContext context,
    required PatientLinkRequest request,
  }) async {
    final contactIdCtl = TextEditingController(
      text: request.targetContactId ?? '',
    );

    final accountNumberCtl = TextEditingController(
      text: request.targetAccountNumber ?? '',
    );

    final contactNameCtl = TextEditingController(
      text: request.targetContactDisplayName ?? '',
    );

    final relationship = ValueNotifier<PatientContactRelationship>(
      request.relationship,
    );

    try {
      return await showDialog<PatientLinkRequestApproveInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve patient link request'),
          content: SizedBox(
            width: 720,
            height: _height(context, fraction: 0.58, min: 340, max: 620),
            child: SingleChildScrollView(
              padding: _scrollPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RequestSummaryBox(request: request),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextFormField(
                          controller: contactIdCtl,
                          decoration: const InputDecoration(
                            labelText: 'Zoho contact ID',
                            helperText:
                                'Optional if account number is provided',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextFormField(
                          controller: accountNumberCtl,
                          decoration: const InputDecoration(
                            labelText: 'Account number',
                            helperText: 'Used when Zoho contact ID is blank',
                            hintText: 'AC-XXXXXX',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: TextFormField(
                          controller: contactNameCtl,
                          decoration: const InputDecoration(
                            labelText: 'Contact display name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                            ValueListenableBuilder<PatientContactRelationship>(
                              valueListenable: relationship,
                              builder: (_, value, __) {
                                return DropdownButtonFormField<
                                  PatientContactRelationship
                                >(
                                  initialValue: value,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Relationship',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: PatientProfilesLabels
                                      .staffLinkRelationships
                                      .map(
                                        (rel) => DropdownMenuItem(
                                          value: rel,
                                          child: Text(
                                            PatientProfilesLabels.relationship(
                                              rel,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  selectedItemBuilder: (context) {
                                    return PatientProfilesLabels
                                        .staffLinkRelationships
                                        .map(
                                          (rel) => Text(
                                            PatientProfilesLabels.relationship(
                                              rel,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                        .toList(growable: false);
                                  },
                                  onChanged: (next) {
                                    if (next != null) relationship.value = next;
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Staff approval needs a real Zoho contact. If only the account number is available, the backend will resolve it before creating the patient-contact link.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final contactId = _cleanNullable(contactIdCtl.text);
                final accountNumber = _cleanNullable(accountNumberCtl.text);

                Navigator.of(context).pop(
                  PatientLinkRequestApproveInput(
                    contactId: contactId,
                    accountNumber: contactId == null ? accountNumber : null,
                    contactDisplayName: _cleanNullable(contactNameCtl.text),
                    relationship: relationship.value,
                  ),
                );
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      );
    } finally {
      contactIdCtl.dispose();
      accountNumberCtl.dispose();
      contactNameCtl.dispose();
      relationship.dispose();
    }
  }

  static Future<PatientLinkRequestRejectInput?> showReject({
    required BuildContext context,
  }) async {
    final reasonCtl = TextEditingController();

    try {
      return await showDialog<PatientLinkRequestRejectInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reject patient link request'),
          content: SizedBox(
            width: 560,
            child: TextFormField(
              controller: reasonCtl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  PatientLinkRequestRejectInput(reason: reasonCtl.text.trim()),
                );
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      );
    } finally {
      reasonCtl.dispose();
    }
  }
}

import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';
import 'package:flutter/material.dart';

class PatientLinkRequestDialogs {
  const PatientLinkRequestDialogs._();

  static Future<PatientProfileLinkToSelfInput?> showLinkToSelf({
    required BuildContext context,
    required PatientProfile patient,
  }) async {
    final relationship = ValueNotifier<ContactPatientRelationship>(
      ContactPatientRelationship.self,
    );

    final gender = ValueNotifier<PatientGender>(
      patient.gender ?? PatientGender.unknown,
    );

    final fullNameCtl = TextEditingController(text: patient.fullName);
    final dobCtl = TextEditingController(text: patient.dob ?? '');
    final phoneCtl = TextEditingController(text: patient.phone ?? '');
    final emailCtl = TextEditingController(text: patient.email ?? '');
    final nationalIdCtl = TextEditingController(text: patient.nationalId ?? '');
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<PatientProfileLinkToSelfInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Link patient to me / my dependent'),
          content: SizedBox(
            width: 720,
            child: Form(
              key: formKey,
              child: ValueListenableBuilder<ContactPatientRelationship>(
                valueListenable: relationship,
                builder: (_, rel, __) {
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                          width: 220,
                          child:
                              DropdownButtonFormField<
                                ContactPatientRelationship
                              >(
                                initialValue: rel,
                                decoration: const InputDecoration(
                                  labelText: 'Relationship to me',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  helperText:
                                      'This creates the safe self/dependent link.',
                                ),
                                items: ContactPatientRelationship.values
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          PatientProfilesLabels.relationship(
                                            value,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value != null) relationship.value = value;
                                },
                              ),
                        ),
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
                          width: 180,
                          child: ValueListenableBuilder<PatientGender>(
                            valueListenable: gender,
                            builder: (_, value, __) {
                              return DropdownButtonFormField<PatientGender>(
                                initialValue: value,
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
                          width: 180,
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
                        const SizedBox(
                          width: 650,
                          child: Text(
                            'To link an existing patient, use the DawaPap patient ID and confirm at least 3 matching identifiers.',
                          ),
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
                  PatientProfileLinkToSelfInput(
                    relationship: relationship.value,
                    confirmFullName: fullNameCtl.text.trim(),
                    confirmGender: gender.value,
                    confirmDob: dobCtl.text.trim(),
                    confirmPhone: phoneCtl.text.trim(),
                    confirmEmail: emailCtl.text.trim(),
                    confirmNationalId: nationalIdCtl.text.trim(),
                  ),
                );
              },
              child: const Text('Link patient'),
            ),
          ],
        ),
      );
    } finally {
      fullNameCtl.dispose();
      dobCtl.dispose();
      phoneCtl.dispose();
      emailCtl.dispose();
      nationalIdCtl.dispose();
      relationship.dispose();
      gender.dispose();
    }
  }

  static Future<PatientLinkRequestCreateInput?> showRequestPayerLink({
    required BuildContext context,
    required PatientProfile patient,
  }) async {
    final relationship = ValueNotifier<ContactPatientRelationship>(
      ContactPatientRelationship.other,
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
          title: const Text('Request another payer/contact'),
          content: SizedBox(
            width: 760,
            child: Form(
              key: formKey,
              child: ValueListenableBuilder<ContactPatientRelationship>(
                valueListenable: relationship,
                builder: (_, rel, __) {
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                          width: 220,
                          child:
                              DropdownButtonFormField<
                                ContactPatientRelationship
                              >(
                                initialValue: rel,
                                decoration: const InputDecoration(
                                  labelText: 'Requested relationship',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  helperText: 'Other requires staff approval.',
                                ),
                                items: ContactPatientRelationship.values
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          PatientProfilesLabels.relationship(
                                            value,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value != null) relationship.value = value;
                                },
                              ),
                        ),
                        const SizedBox(
                          width: 720,
                          child: Text(
                            'Tell us who should be linked as a payer/contact. Staff will review the request before sensitive or billing-related links are applied.',
                          ),
                        ),
                        SizedBox(
                          width: 330,
                          child: TextFormField(
                            controller: payerNameCtl,
                            decoration: const InputDecoration(
                              labelText: 'Payer/contact name',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: accountNumberCtl,
                            decoration: const InputDecoration(
                              labelText: 'Account number if known',
                              hintText: 'AC-XXXXXX',
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
                        const Divider(),
                        const SizedBox(
                          width: 720,
                          child: Text(
                            'Confirm at least 3 patient identifiers. This protects patients from being linked to the wrong payer/contact.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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
                          width: 180,
                          child: ValueListenableBuilder<PatientGender>(
                            valueListenable: gender,
                            builder: (_, value, __) {
                              return DropdownButtonFormField<PatientGender>(
                                initialValue: value,
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
                          width: 180,
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

  static Future<PatientLinkRequestApproveInput?> showApproveLinkRequest({
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

    final relationship = ValueNotifier<ContactPatientRelationship>(
      request.relationship,
    );

    String? clean(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    try {
      return await showDialog<PatientLinkRequestApproveInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve patient link request'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  RequestSummaryBox(request: request),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: contactIdCtl,
                      decoration: const InputDecoration(
                        labelText: 'Zoho contact ID',
                        helperText: 'Optional if account number is provided',
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
                    width: 220,
                    child: ValueListenableBuilder<ContactPatientRelationship>(
                      valueListenable: relationship,
                      builder: (_, value, __) {
                        return DropdownButtonFormField<
                          ContactPatientRelationship
                        >(
                          initialValue: value,
                          decoration: const InputDecoration(
                            labelText: 'Relationship',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: ContactPatientRelationship.values
                              .map(
                                (rel) => DropdownMenuItem(
                                  value: rel,
                                  child: Text(
                                    PatientProfilesLabels.relationship(rel),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (next) {
                            if (next != null) relationship.value = next;
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 680,
                    child: Text(
                      'Staff approval needs a real Zoho contact. If only the account number is available, the backend will resolve it to the Zoho contact ID before creating the patient-contact link.',
                    ),
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
                final contactId = clean(contactIdCtl.text);
                final accountNumber = clean(accountNumberCtl.text);

                Navigator.of(context).pop(
                  PatientLinkRequestApproveInput(
                    contactId: contactId,
                    accountNumber: contactId == null ? accountNumber : null,
                    contactDisplayName: clean(contactNameCtl.text),
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

  static Future<PatientLinkRequestRejectInput?> showRejectLinkRequest({
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

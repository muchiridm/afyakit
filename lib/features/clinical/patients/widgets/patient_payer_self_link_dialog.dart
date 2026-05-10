// lib/features/clinical/patients/widgets/patient_link_self_dialog.dart

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';
import 'package:flutter/material.dart';

class PatientLinkSelfDialog {
  const PatientLinkSelfDialog._();

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

  static Future<PatientProfileLinkToSelfInput?> show({
    required BuildContext context,
    required PatientProfile patient,
  }) async {
    final relationship = ValueNotifier<PatientContactRelationship>(
      PatientContactRelationship.self,
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
          title: const Text('Link existing patient'),
          content: SizedBox(
            width: 720,
            height: _height(context, fraction: 0.62, min: 360, max: 640),
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
                                      labelText: 'Relationship to me',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      helperText: 'Self/dependent links only.',
                                    ),
                                    items: PatientProfilesLabels
                                        .selfLinkRelationships
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
                                          .selfLinkRelationships
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
                          'Confirm at least 3 patient identifiers before linking this patient to your account.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
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
                              width: 180,
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
}

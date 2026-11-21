// lib/features/records/health_profiles/widgets/profile_payer_self_link_dialog.dart

import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_labels.dart';
import 'package:flutter/material.dart';

class ProfileLinkSelfDialog {
  const ProfileLinkSelfDialog._();

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

  static Future<ProfileLinkToSelfInput?> show({
    required BuildContext context,
    required Profile patient,
  }) async {
    final relationship = ValueNotifier<ProfileContactRelationship>(
      ProfileContactRelationship.self,
    );

    final gender = ValueNotifier<ProfileGender>(
      patient.gender ?? ProfileGender.unknown,
    );

    final fullNameCtl = TextEditingController(text: patient.fullName);
    final dobCtl = TextEditingController(text: patient.dob ?? '');
    final phoneCtl = TextEditingController(text: patient.phone ?? '');
    final emailCtl = TextEditingController(text: patient.email ?? '');
    final nationalIdCtl = TextEditingController(text: patient.nationalId ?? '');
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<ProfileLinkToSelfInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Link existing patient'),
          content: SizedBox(
            width: 720,
            height: _height(context, fraction: 0.62, min: 360, max: 640),
            child: Form(
              key: formKey,
              child: ValueListenableBuilder<ProfileContactRelationship>(
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
                                child: SelectableText(patient.profileId),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child:
                                  DropdownButtonFormField<
                                    ProfileContactRelationship
                                  >(
                                    initialValue: rel,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Relationship to me',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      helperText: 'Self/dependent links only.',
                                    ),
                                    items: ProfilesLabels.selfLinkRelationships
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(
                                              ProfilesLabels.relationship(
                                                value,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    selectedItemBuilder: (context) {
                                      return ProfilesLabels
                                          .selfLinkRelationships
                                          .map(
                                            (value) => Text(
                                              ProfilesLabels.relationship(
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
                          'Confirm at least 3 patient identifiers before linking this profile to your account.',
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
                              child: ValueListenableBuilder<ProfileGender>(
                                valueListenable: gender,
                                builder: (_, value, __) {
                                  return DropdownButtonFormField<ProfileGender>(
                                    initialValue: value,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm gender',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: ProfileGender.values
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(
                                              ProfilesLabels.gender(g),
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
                  ProfileLinkToSelfInput(
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

/// Request association with an existing Profile without reading its records.
/// The server resolves the member's Contact from their authenticated session.
class ExistingProfileLinkRequestDialog extends StatefulWidget {
  const ExistingProfileLinkRequestDialog({super.key});

  static Future<({String profileId, ProfileLinkRequestCreateInput input})?>
  show(BuildContext context) =>
      showDialog<({String profileId, ProfileLinkRequestCreateInput input})>(
        context: context,
        builder: (_) => const ExistingProfileLinkRequestDialog(),
      );

  @override
  State<ExistingProfileLinkRequestDialog> createState() =>
      _ExistingProfileLinkRequestDialogState();
}

class _ExistingProfileLinkRequestDialogState
    extends State<ExistingProfileLinkRequestDialog> {
  final _key = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _reason = TextEditingController();
  ProfileContactRelationship _relationship = ProfileContactRelationship.self;
  ProfileGender? _gender;

  @override
  void dispose() {
    for (final ctl in [
      _id,
      _name,
      _dob,
      _phone,
      _email,
      _nationalId,
      _reason,
    ]) {
      ctl.dispose();
    }
    super.dispose();
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  void _submit() {
    if (!(_key.currentState?.validate() ?? false)) return;
    // Do not prefetch patient demographics or validate identity on device.
    // Backend verifies at least three matching identifiers before accepting.
    final identifiers = [
      _optional(_name.text),
      _gender?.name,
      _optional(_dob.text),
      _optional(_phone.text),
      _optional(_email.text),
      _optional(_nationalId.text),
    ].where((v) => v != null).length;
    if (identifiers < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least three identifiers for verification.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((
      profileId: _id.text.trim(),
      input: ProfileLinkRequestCreateInput(
        relationship: _relationship,
        reason: _optional(_reason.text),
        confirmFullName: _optional(_name.text),
        confirmGender: _gender,
        confirmDob: _optional(_dob.text),
        confirmPhone: _optional(_phone.text),
        confirmEmail: _optional(_email.text),
        confirmNationalId: _optional(_nationalId.text),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request existing Health Profile'),
    content: SizedBox(
      width: 600,
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: Form(
        key: _key,
        child: ListView(
          children: [
            const Text(
              'Your Native Contact is determined securely from your sign-in. '
              'A staff member must approve this request before the Profile is linked.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _id,
              decoration: const InputDecoration(
                labelText: 'Existing Health Profile ID',
                hintText: 'HP-YYMMNNNN',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty || v.contains('/')
                  ? 'Enter a valid Profile ID'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProfileContactRelationship>(
              initialValue: _relationship,
              decoration: const InputDecoration(
                labelText: 'Patient is my…',
                border: OutlineInputBorder(),
              ),
              items:
                  const [
                        ProfileContactRelationship.self,
                        ProfileContactRelationship.child,
                        ProfileContactRelationship.spouse,
                        ProfileContactRelationship.parent,
                        ProfileContactRelationship.guardian,
                        ProfileContactRelationship.other,
                      ]
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(ProfilesLabels.relationship(r)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _relationship = value);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Provide at least three matching identifiers. Incorrect details will be rejected. '
              'No Profile information is displayed before approval.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Patient full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ProfileGender?>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Patient gender (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<ProfileGender?>(
                  value: null,
                  child: Text('Not provided'),
                ),
                ...ProfileGender.values.map(
                  (g) => DropdownMenuItem<ProfileGender?>(
                    value: g,
                    child: Text(ProfilesLabels.gender(g)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _dob,
              decoration: const InputDecoration(
                labelText: 'Date of birth (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null ||
                      v.trim().isEmpty ||
                      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v.trim())
                  ? null
                  : 'Use YYYY-MM-DD',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Patient phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Patient email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nationalId,
              decoration: const InputDecoration(
                labelText: 'Patient national ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Submit for review')),
    ],
  );
}

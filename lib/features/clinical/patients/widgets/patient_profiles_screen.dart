// lib/features/clinical/patients/widgets/patient_profiles_screen.dart

import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PatientProfilesScreen extends ConsumerStatefulWidget {
  const PatientProfilesScreen({
    super.key,
    this.allowExplicitContactLink = false,
  });

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  @override
  ConsumerState<PatientProfilesScreen> createState() =>
      _PatientProfilesScreenState();
}

class _PatientProfilesScreenState extends ConsumerState<PatientProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _contactIdCtl;

  ContactPatientRelationship? _relationship;

  @override
  void initState() {
    super.initState();
    _searchCtl = TextEditingController();
    _contactIdCtl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final controller = ref.read(patientProfilesControllerProvider.notifier);

      if (widget.allowExplicitContactLink) {
        controller.loadLinkRequests(
          status: PatientLinkRequestStatus.pendingStaffApproval,
        );
      } else {
        controller.loadLinkRequests();
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _contactIdCtl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) => PatientProfileFormDialog(
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await ref.read(patientProfilesControllerProvider.notifier).create(input);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile created')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openEditDialog(PatientProfile patient) async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) => PatientProfileFormDialog(
        initial: patient,
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .update(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile updated')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _deletePatient(PatientProfile patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete patient profile'),
        content: Text('Delete ${patient.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .remove(patient.patientId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile deleted')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openLinkToSelfDialog(PatientProfile patient) async {
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
      final input = await showDialog<PatientProfileLinkToSelfInput>(
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
                                        child: Text(_relationshipLabel(value)),
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
                                        child: Text(_genderLabel(g)),
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

      if (input == null || !mounted) return;

      await ref
          .read(patientProfilesControllerProvider.notifier)
          .linkToSelf(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient linked successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
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

  Future<void> _openRequestPayerLinkDialog(PatientProfile patient) async {
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
      final input = await showDialog<PatientLinkRequestCreateInput>(
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
                                        child: Text(_relationshipLabel(value)),
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
                                        child: Text(_genderLabel(g)),
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

      if (input == null || !mounted) return;

      await ref
          .read(patientProfilesControllerProvider.notifier)
          .requestPayerLink(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request submitted')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
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

  Future<void> _openApproveLinkRequestDialog(PatientLinkRequest request) async {
    final contactIdCtl = TextEditingController(
      text: request.targetContactId ?? '',
    );

    final contactNameCtl = TextEditingController(
      text: request.targetContactDisplayName ?? '',
    );

    final relationship = ValueNotifier<ContactPatientRelationship>(
      request.relationship,
    );

    try {
      final input = await showDialog<PatientLinkRequestApproveInput>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve patient link request'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _requestSummaryBox(request),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: contactIdCtl,
                      decoration: const InputDecoration(
                        labelText: 'Zoho contact ID',
                        helperText: 'Required for staff approval',
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
                                  child: Text(_relationshipLabel(rel)),
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
                Navigator.of(context).pop(
                  PatientLinkRequestApproveInput(
                    contactId: contactIdCtl.text.trim(),
                    contactDisplayName: contactNameCtl.text.trim(),
                    relationship: relationship.value,
                  ),
                );
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (input == null || !mounted) return;

      await ref
          .read(patientProfilesControllerProvider.notifier)
          .approveLinkRequest(request.requestId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request approved')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    } finally {
      contactIdCtl.dispose();
      contactNameCtl.dispose();
      relationship.dispose();
    }
  }

  Future<void> _openRejectLinkRequestDialog(PatientLinkRequest request) async {
    final reasonCtl = TextEditingController();

    try {
      final input = await showDialog<PatientLinkRequestRejectInput>(
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

      if (input == null || !mounted) return;

      await ref
          .read(patientProfilesControllerProvider.notifier)
          .rejectLinkRequest(request.requestId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request rejected')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    } finally {
      reasonCtl.dispose();
    }
  }

  void _showErrorFromState() {
    final error = ref.read(patientProfilesControllerProvider).error;
    if (error == null || error.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String _relationshipLabel(ContactPatientRelationship value) {
    switch (value) {
      case ContactPatientRelationship.self:
        return 'Self';
      case ContactPatientRelationship.child:
        return 'Child';
      case ContactPatientRelationship.spouse:
        return 'Spouse';
      case ContactPatientRelationship.parent:
        return 'Parent';
      case ContactPatientRelationship.guardian:
        return 'Guardian';
      case ContactPatientRelationship.other:
        return 'Other';
    }
  }

  String _genderLabel(PatientGender value) {
    switch (value) {
      case PatientGender.male:
        return 'Male';
      case PatientGender.female:
        return 'Female';
      case PatientGender.other:
        return 'Other';
      case PatientGender.unknown:
        return 'Unknown';
    }
  }

  String _statusLabel(PatientLinkRequestStatus value) {
    switch (value) {
      case PatientLinkRequestStatus.pendingOwnerApproval:
        return 'Pending owner approval';
      case PatientLinkRequestStatus.pendingStaffApproval:
        return 'Pending staff approval';
      case PatientLinkRequestStatus.approved:
        return 'Approved';
      case PatientLinkRequestStatus.rejected:
        return 'Rejected';
      case PatientLinkRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _approvalModeLabel(PatientLinkApprovalMode value) {
    switch (value) {
      case PatientLinkApprovalMode.owner:
        return 'Owner approval';
      case PatientLinkApprovalMode.staff:
        return 'Staff approval';
    }
  }

  String _nullable(String? value, {String fallback = '—'}) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  Widget _infoLine(String label, String value) {
    return Text('$label: $value');
  }

  Widget _linkedContactsView(PatientProfile patient) {
    if (patient.linkedContacts.isEmpty) {
      final contextualContact = patient.contactDisplayName ?? patient.contactId;

      return _infoLine('Linked contacts', _nullable(contextualContact));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Linked contacts:'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: patient.linkedContacts
              .map((link) {
                final title = link.contactDisplayName?.trim().isNotEmpty == true
                    ? link.contactDisplayName!.trim()
                    : link.contactId;

                final relationship = _relationshipLabel(link.relationship);
                final status = link.isActive ? 'Active' : 'Inactive';

                return Chip(
                  label: Text('$title · $relationship · $status'),
                  visualDensity: VisualDensity.compact,
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _contextualContactView(PatientProfile patient) {
    final contact = patient.contactDisplayName ?? patient.contactId;
    final relationship = patient.relationship;

    if (_nullable(contact).trim() == '—' && relationship == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Current association: ${_nullable(contact)}'
        '${relationship == null ? '' : ' · ${_relationshipLabel(relationship)}'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _patientCard(PatientProfile patient, PatientProfilesState state) {
    return Card(
      child: ListTile(
        title: Text(patient.fullName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('ID', patient.patientId),
              _infoLine('DOB', _nullable(patient.dob)),
              _infoLine(
                'Gender',
                patient.gender == null ? '—' : _genderLabel(patient.gender!),
              ),
              _infoLine('Phone', _nullable(patient.phone)),
              _infoLine('Email', _nullable(patient.email)),
              _infoLine('National ID', _nullable(patient.nationalId)),
              const SizedBox(height: 6),
              _linkedContactsView(patient),
              _contextualContactView(patient),
              const SizedBox(height: 6),
              _infoLine('Status', patient.isActive ? 'Active' : 'Inactive'),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Link to me / my dependent',
              onPressed: state.isSaving
                  ? null
                  : () => _openLinkToSelfDialog(patient),
              icon: const Icon(Icons.link),
            ),
            IconButton(
              tooltip: 'Request another payer/contact',
              onPressed: state.isSaving
                  ? null
                  : () => _openRequestPayerLinkDialog(patient),
              icon: const Icon(Icons.add_link),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: state.isSaving ? null : () => _openEditDialog(patient),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: state.isSaving ? null : () => _deletePatient(patient),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestSummaryBox(PatientLinkRequest request) {
    return SizedBox(
      width: 640,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodySmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.patientDisplayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text('Patient ID: ${request.patientId}'),
                Text('Requested target: ${request.bestTargetLabel}'),
                Text(
                  'Relationship: ${_relationshipLabel(request.relationship)}',
                ),
                Text('Status: ${_statusLabel(request.status)}'),
                Text('Approval: ${_approvalModeLabel(request.approvalMode)}'),
                if (request.matchesCount != null)
                  Text('Identifier matches: ${request.matchesCount}'),
                if (request.reason?.trim().isNotEmpty == true)
                  Text('Reason: ${request.reason!.trim()}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkRequestCard(
    PatientLinkRequest request,
    PatientProfilesState state,
  ) {
    final pending = request.isPending;

    return Card(
      child: ListTile(
        title: Text(
          '${request.patientDisplayName} → ${request.bestTargetLabel}',
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('Patient ID', request.patientId),
              _infoLine(
                'Relationship',
                _relationshipLabel(request.relationship),
              ),
              _infoLine('Status', _statusLabel(request.status)),
              _infoLine('Approval', _approvalModeLabel(request.approvalMode)),
              if (request.matchesCount != null)
                _infoLine('Identifier matches', '${request.matchesCount}'),
              if (request.reason?.trim().isNotEmpty == true)
                _infoLine('Reason', request.reason!.trim()),
            ],
          ),
        ),
        trailing: pending
            ? Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: state.isSaving
                        ? null
                        : () => _openApproveLinkRequestDialog(request),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    onPressed: state.isSaving
                        ? null
                        : () => _openRejectLinkRequestDialog(request),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _linkRequestsPanel(PatientProfilesState state) {
    if (!widget.allowExplicitContactLink && state.linkRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    final title = widget.allowExplicitContactLink
        ? 'Pending link requests'
        : 'My link requests';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ExpansionTile(
        initiallyExpanded:
            widget.allowExplicitContactLink && state.linkRequests.isNotEmpty,
        tilePadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(
          state.isLoadingLinkRequests
              ? 'Loading…'
              : '${state.linkRequests.length} request(s)',
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (state.isLoadingLinkRequests)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              tooltip: 'Refresh requests',
              onPressed: state.isLoadingLinkRequests
                  ? null
                  : () {
                      ref
                          .read(patientProfilesControllerProvider.notifier)
                          .loadLinkRequests(
                            status: widget.allowExplicitContactLink
                                ? PatientLinkRequestStatus.pendingStaffApproval
                                : null,
                            resetStatus: !widget.allowExplicitContactLink,
                          );
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        children: [
          if (state.linkRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No link requests found'),
              ),
            )
          else
            ...state.linkRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _linkRequestCard(request, state),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientProfilesControllerProvider);
    final controller = ref.read(patientProfilesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient profiles'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading ? null : controller.refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: state.isSaving ? null : _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add patient'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _linkRequestsPanel(state),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtl,
                    decoration: const InputDecoration(
                      labelText: 'Search patients',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      controller.applyFilters(search: value);
                    },
                  ),
                ),
                if (widget.allowExplicitContactLink)
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _contactIdCtl,
                      decoration: const InputDecoration(
                        labelText: 'Associated contact ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        controller.applyFilters(contactId: value);
                      },
                    ),
                  ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<ContactPatientRelationship?>(
                    initialValue: _relationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<ContactPatientRelationship?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...ContactPatientRelationship.values.map(
                        (value) =>
                            DropdownMenuItem<ContactPatientRelationship?>(
                              value: value,
                              child: Text(_relationshipLabel(value)),
                            ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _relationship = value);
                      controller.applyFilters(
                        relationship: value,
                        resetRelationship: value == null,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: state.isActive == null
                        ? 'all'
                        : (state.isActive! ? 'active' : 'inactive'),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == 'all') {
                        controller.applyFilters(resetIsActive: true);
                      } else {
                        controller.applyFilters(isActive: value == 'active');
                      }
                    },
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    _searchCtl.clear();
                    _contactIdCtl.clear();
                    setState(() => _relationship = null);
                    controller.clearFilters();
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
          if (state.error != null && state.error!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                ? const Center(child: Text('No patient profiles found'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final patient = state.items[index];
                      return _patientCard(patient, state);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

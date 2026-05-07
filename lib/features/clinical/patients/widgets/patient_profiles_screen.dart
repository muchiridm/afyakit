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
                                value: rel,
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
                          child: DropdownButtonFormField<PatientGender>(
                            value: patient.gender ?? PatientGender.unknown,
                            decoration: const InputDecoration(
                              labelText: 'Confirm gender',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: PatientGender.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(_genderLabel(value)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: null,
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
                    confirmGender: patient.gender ?? PatientGender.unknown,
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

  String _nullable(String? value, {String fallback = '—'}) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
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
            onPressed: state.isLoading ? null : controller.refresh,
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
                    value: _relationship,
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
                    value: state.isActive == null
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
                      final linkedContact =
                          patient.contactDisplayName ?? patient.contactId;

                      return Card(
                        child: ListTile(
                          title: Text(patient.fullName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('DP ID: ${patient.patientId}'),
                              Text('DOB: ${_nullable(patient.dob)}'),
                              Text(
                                'Gender: ${patient.gender == null ? '—' : _genderLabel(patient.gender!)}',
                              ),
                              Text('Phone: ${_nullable(patient.phone)}'),
                              Text('Email: ${_nullable(patient.email)}'),
                              Text(
                                'National ID: ${_nullable(patient.nationalId)}',
                              ),
                              Text(
                                'Associated contact: ${_nullable(linkedContact)}',
                              ),
                              Text(
                                'Relationship: ${patient.relationship == null ? '—' : _relationshipLabel(patient.relationship!)}',
                              ),
                              Text(
                                patient.isActive
                                    ? 'Status: Active'
                                    : 'Status: Inactive',
                              ),
                            ],
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
                                tooltip: 'Edit',
                                onPressed: state.isSaving
                                    ? null
                                    : () => _openEditDialog(patient),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: state.isSaving
                                    ? null
                                    : () => _deletePatient(patient),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

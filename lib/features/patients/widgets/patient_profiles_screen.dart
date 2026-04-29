// lib/features/patients/widgets/patient_profiles_screen.dart

import 'package:afyakit/features/patients/controllers/patient_profiles_controller.dart';
import 'package:afyakit/features/patients/models/patient_profile.dart';
import 'package:afyakit/features/patients/widgets/patient_profile_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PatientProfilesScreen extends ConsumerStatefulWidget {
  const PatientProfilesScreen({super.key});

  @override
  ConsumerState<PatientProfilesScreen> createState() =>
      _PatientProfilesScreenState();
}

class _PatientProfilesScreenState extends ConsumerState<PatientProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _insuranceCtl;
  late final TextEditingController _schemeCtl;

  @override
  void initState() {
    super.initState();
    _searchCtl = TextEditingController();
    _insuranceCtl = TextEditingController();
    _schemeCtl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _insuranceCtl.dispose();
    _schemeCtl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) => const PatientProfileFormDialog(),
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
      builder: (_) => PatientProfileFormDialog(initial: patient),
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

  void _showErrorFromState() {
    final error = ref.read(patientProfilesControllerProvider).error;
    if (error == null || error.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      controller.applyFilters(search: value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _insuranceCtl,
                    decoration: const InputDecoration(
                      labelText: 'Insurance',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      controller.applyFilters(insurance: value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _schemeCtl,
                    decoration: const InputDecoration(
                      labelText: 'Scheme',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      controller.applyFilters(scheme: value);
                    },
                  ),
                ),
                DropdownButtonFormField<String>(
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
                OutlinedButton(
                  onPressed: () {
                    _searchCtl.clear();
                    _insuranceCtl.clear();
                    _schemeCtl.clear();
                    controller.applyFilters(
                      search: '',
                      insurance: '',
                      scheme: '',
                      resetIsActive: true,
                    );
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

                      return Card(
                        child: ListTile(
                          title: Text(patient.fullName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('DOB: ${patient.dob}'),
                              Text('Member #: ${patient.memberNumber}'),
                              Text(
                                'Insurance: ${patient.insurance} • Scheme: ${patient.scheme}',
                              ),
                              Text(
                                'Payer: ${patient.payerDisplayName ?? patient.payerContactId}',
                              ),
                              Text(
                                patient.isActive
                                    ? 'Status: Active'
                                    : 'Status: Inactive',
                              ),
                            ],
                          ),
                          isThreeLine: false,
                          trailing: Wrap(
                            spacing: 8,
                            children: [
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

// lib/features/clinical/patients/widgets/patient_picker.dart

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PatientPickerCard extends StatelessWidget {
  const PatientPickerCard({
    super.key,
    required this.selectedPatient,
    required this.busy,
    required this.onChanged,
    this.contactId,
    this.forcePickerMode = false,
  });

  final PatientProfile? selectedPatient;
  final bool busy;
  final ValueChanged<PatientProfile> onChanged;

  /// Member/contact scope.
  ///
  /// When provided, the picker only loads patients linked to this contact.
  /// Staff flows can omit this to search all patients.
  final String? contactId;

  /// Use true in staff/admin flows where you explicitly want all patients,
  /// even if a contactId is available in the surrounding context.
  final bool forcePickerMode;

  String? get _scopeContactId {
    if (forcePickerMode) return null;

    final id = (contactId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  @override
  Widget build(BuildContext context) {
    final patient = selectedPatient;
    final scoped = _scopeContactId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(
                patient == null
                    ? Icons.person_search_outlined
                    : Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: patient == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scoped ? 'Select patient profile' : 'Select patient',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scoped
                              ? 'Choose from your linked patient profiles.'
                              : 'Choose the patient profile to continue.',
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            patient.patientId,
                            if ((patient.dob ?? '').trim().isNotEmpty)
                              'DOB: ${patient.dob}',
                            if ((patient.phone ?? '').trim().isNotEmpty)
                              patient.phone,
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDialog<PatientProfile>(
                        context: context,
                        builder: (_) =>
                            PatientPickerDialog(contactId: _scopeContactId),
                      );

                      if (picked != null) onChanged(picked);
                    },
              icon: const Icon(Icons.search),
              label: Text(patient == null ? 'Pick' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientPickerDialog extends ConsumerStatefulWidget {
  const PatientPickerDialog({super.key, this.contactId});

  final String? contactId;

  @override
  ConsumerState<PatientPickerDialog> createState() =>
      _PatientPickerDialogState();
}

class _PatientPickerDialogState extends ConsumerState<PatientPickerDialog> {
  final _searchController = TextEditingController();

  PatientProfilesScope get _scope {
    final contactId = (widget.contactId ?? '').trim();

    return PatientProfilesScope(
      contactId: contactId.isEmpty ? null : contactId,
      allowExplicitContactLink: false,
    );
  }

  bool get _isMemberScoped => (widget.contactId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(patientProfilesControllerProvider(_scope).notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(PatientProfilesController controller) {
    return controller.applyFilters(search: _searchController.text);
  }

  Future<void> _clear(PatientProfilesController controller) async {
    _searchController.clear();
    setState(() {});
    await controller.applyFilters(search: '');
  }

  Future<void> _addPatient(PatientProfilesController controller) async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) =>
          PatientProfileFormDialog(allowExplicitContactLink: !_isMemberScoped),
    );

    if (input == null || !mounted) return;

    try {
      final created = await controller.create(input);

      if (!mounted) return;

      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create patient profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientProfilesControllerProvider(_scope));
    final controller = ref.read(
      patientProfilesControllerProvider(_scope).notifier,
    );

    return AlertDialog(
      title: Text(_isMemberScoped ? 'Select profile' : 'Select patient'),
      content: SizedBox(
        width: 620,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: _isMemberScoped
                    ? 'Search your profiles'
                    : 'Search patient',
                hintText: _isMemberScoped
                    ? 'Name, patient no., phone...'
                    : 'Name, patient no., phone, ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: state.isLoading
                            ? null
                            : () => _clear(controller),
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(controller),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.isLoading
                        ? 'Loading profiles...'
                        : _isMemberScoped
                        ? '${state.items.length} linked profile(s)'
                        : '${state.items.length} patient(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: state.isLoading || state.isSaving
                      ? null
                      : () => _addPatient(controller),
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(_isMemberScoped ? 'Add profile' : 'Add patient'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (state.error != null)
              _PickerErrorBanner(message: state.error!)
            else if (state.isLoading && state.items.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _isMemberScoped
                        ? 'No linked patient profiles found.'
                        : 'No patients found.',
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final patient = state.items[index];

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        patient.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          patient.patientId,
                          if ((patient.dob ?? '').trim().isNotEmpty)
                            'DOB: ${patient.dob}',
                          if ((patient.phone ?? '').trim().isNotEmpty)
                            patient.phone,
                          if (patient.relationship != null)
                            patient.relationship!.name,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, patient),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PickerErrorBanner extends StatelessWidget {
  const _PickerErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(message),
          ),
        ),
      ),
    );
  }
}

// lib/features/retail/quotes/widgets/quote_patient_membership_picker_dialog.dart

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuotePatientContextSelection {
  const QuotePatientContextSelection({
    required this.patientSnapshot,
    this.membershipId,
    this.payerContact,
  });

  final SalesDocumentPatientSnapshot patientSnapshot;
  final String? membershipId;

  /// Present only when the selected context came from an insurance membership.
  ///
  /// Insurance quotes must be billed to the payer/insurer, not the patient.
  final ZohoContact? payerContact;

  bool get hasMembership => (membershipId ?? '').trim().isNotEmpty;

  bool get hasPayerContact => (payerContact?.contactId ?? '').trim().isNotEmpty;
}

class QuotePatientMembershipPickerDialog extends ConsumerStatefulWidget {
  const QuotePatientMembershipPickerDialog({
    super.key,
    this.initialPatientId,
    this.initialMembershipId,
  });

  final String? initialPatientId;
  final String? initialMembershipId;

  @override
  ConsumerState<QuotePatientMembershipPickerDialog> createState() =>
      _QuotePatientMembershipPickerDialogState();
}

class _QuotePatientMembershipPickerDialogState
    extends ConsumerState<QuotePatientMembershipPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtl;

  final _patientSearchCtl = TextEditingController();
  final _membershipSearchCtl = TextEditingController();

  /// Staff quote flow: show all tenant patient profiles.
  ///
  /// Member/customer quote flows should use a member-scoped picker later,
  /// passing the authenticated contactId into PatientProfilesScope.
  static const PatientProfilesScope _patientScope = PatientProfilesScope(
    allowExplicitContactLink: true,
  );

  @override
  void initState() {
    super.initState();

    _tabCtl = TabController(length: 2, vsync: this);

    Future<void>.microtask(() async {
      final patientsController = ref.read(
        patientProfilesControllerProvider(_patientScope).notifier,
      );

      patientsController.setIsActive(true);
      await patientsController.load();

      await ref
          .read(insuranceMembershipsControllerProvider.notifier)
          .load(isActive: true, perPage: 200, page: 1);

      if (!mounted) return;

      final initialMembershipId = (widget.initialMembershipId ?? '').trim();
      if (initialMembershipId.isNotEmpty) {
        _tabCtl.index = 1;
      }
    });
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    _patientSearchCtl.dispose();
    _membershipSearchCtl.dispose();
    super.dispose();
  }

  String _clean(String? value) => (value ?? '').trim();

  bool _contains(String source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return source.toLowerCase().contains(q);
  }

  String _membershipSubtitle(InsuranceMembership membership) {
    final parts = <String>[
      membership.payerLabel,
      if (_clean(membership.scheme).isNotEmpty) membership.scheme!,
      if (_clean(membership.memberNo).isNotEmpty)
        'Member ${membership.memberNo}',
      if (_clean(membership.policyNo).isNotEmpty)
        'Policy ${membership.policyNo}',
      if (_clean(membership.medicalCardNo).isNotEmpty)
        'Card ${membership.medicalCardNo}',
    ];

    return parts.where((p) => p.trim().isNotEmpty).join(' · ');
  }

  QuotePatientContextSelection _selectionFromPatient(PatientProfile patient) {
    final gender = patient.gender?.name;
    final relationship = patient.relationship?.name;

    return QuotePatientContextSelection(
      patientSnapshot: SalesDocumentPatientSnapshot(
        patientId: patient.patientId,
        patientNo: patient.patientId,
        fullName: patient.fullName,
        dob: patient.dob,
        gender: gender,
        relationship: relationship,
      ),
    );
  }

  QuotePatientContextSelection _selectionFromMembership(
    InsuranceMembership membership,
  ) {
    final patientName = _clean(membership.patientDisplayName).isNotEmpty
        ? membership.patientDisplayName!.trim()
        : membership.patientId.trim();

    final payerDisplayName = _clean(membership.payerDisplayName).isNotEmpty
        ? membership.payerDisplayName!.trim()
        : membership.payerContactId.trim();

    final payerContact = ZohoContact(
      contactId: membership.payerContactId.trim(),
      displayName: payerDisplayName,
      accountNumber: _clean(membership.payerAccountNumber).isEmpty
          ? null
          : membership.payerAccountNumber!.trim(),
      contactType: 'customer',
      isInsurancePayer: true,
    );

    return QuotePatientContextSelection(
      membershipId: membership.membershipId,
      payerContact: payerContact,
      patientSnapshot: SalesDocumentPatientSnapshot(
        patientId: membership.patientId,
        patientNo: membership.patientNo ?? membership.patientId,
        fullName: patientName,
        membershipId: membership.membershipId,
        memberNo: membership.memberNo,
        scheme: membership.scheme,
        payerName: payerDisplayName,
      ),
    );
  }

  List<PatientProfile> _filteredPatients(List<PatientProfile> items) {
    final q = _patientSearchCtl.text.trim();

    return items
        .where((p) {
          if (!p.isActive) return false;

          final haystack = [
            p.patientId,
            p.fullName,
            p.dob,
            p.phone,
            p.email,
            p.nationalId,
            p.contactDisplayName,
            p.relationship?.name,
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  List<InsuranceMembership> _filteredMemberships(
    List<InsuranceMembership> items,
  ) {
    final q = _membershipSearchCtl.text.trim();

    return items
        .where((m) {
          if (!m.isActive) return false;

          final haystack = [
            m.membershipId,
            m.patientId,
            m.patientNo,
            m.patientDisplayName,
            m.payerDisplayName,
            m.payerAccountNumber,
            m.memberNo,
            m.memberName,
            m.principalName,
            m.scheme,
            m.medicalCardNo,
            m.policyNo,
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  void _selectPatient(PatientProfile patient) {
    Navigator.of(context).pop(_selectionFromPatient(patient));
  }

  void _selectMembership(InsuranceMembership membership) {
    Navigator.of(context).pop(_selectionFromMembership(membership));
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(
      patientProfilesControllerProvider(_patientScope),
    );
    final membershipsState = ref.watch(insuranceMembershipsControllerProvider);

    final patients = _filteredPatients(patientsState.items);
    final memberships = _filteredMemberships(membershipsState.items);

    final isLoading = patientsState.isLoading || membershipsState.isLoading;

    return AlertDialog(
      title: const Text('Select patient'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            if (isLoading) const LinearProgressIndicator(minHeight: 2),
            TabBar(
              controller: _tabCtl,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline), text: 'Patient'),
                Tab(
                  icon: Icon(Icons.health_and_safety_outlined),
                  text: 'Insurance',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabCtl,
                children: [
                  _PatientTab(
                    searchCtl: _patientSearchCtl,
                    patients: patients,
                    error: patientsState.error,
                    selectedPatientId: widget.initialPatientId,
                    onSearchChanged: (_) => setState(() {}),
                    onRefresh: () => ref
                        .read(
                          patientProfilesControllerProvider(
                            _patientScope,
                          ).notifier,
                        )
                        .load(),
                    onSelect: _selectPatient,
                  ),
                  _MembershipTab(
                    searchCtl: _membershipSearchCtl,
                    memberships: memberships,
                    error: membershipsState.error,
                    selectedMembershipId: widget.initialMembershipId,
                    onSearchChanged: (_) => setState(() {}),
                    onRefresh: () => ref
                        .read(insuranceMembershipsControllerProvider.notifier)
                        .load(isActive: true, perPage: 200, page: 1),
                    onSelect: _selectMembership,
                    subtitleBuilder: _membershipSubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PatientTab extends StatelessWidget {
  const _PatientTab({
    required this.searchCtl,
    required this.patients,
    required this.error,
    required this.selectedPatientId,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSelect,
  });

  final TextEditingController searchCtl;
  final List<PatientProfile> patients;
  final String? error;
  final String? selectedPatientId;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<PatientProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchBox(
          controller: searchCtl,
          label: 'Search patients',
          hint: 'Name, patient no, phone, contact...',
          onChanged: onSearchChanged,
          onRefresh: onRefresh,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ErrorText(error!),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: patients.isEmpty
              ? const _EmptyText(
                  icon: Icons.person_off_outlined,
                  text: 'No active patients found.',
                )
              : ListView.separated(
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final selected =
                        patient.patientId.trim() ==
                        (selectedPatientId ?? '').trim();

                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          selected ? Icons.check : Icons.person_outline,
                        ),
                      ),
                      title: Text(
                        patient.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _subtitle(patient),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FilledButton(
                        onPressed: () => onSelect(patient),
                        child: Text(selected ? 'Selected' : 'Use'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _subtitle(PatientProfile patient) {
    final parts = <String>[
      patient.patientId,
      if ((patient.dob ?? '').trim().isNotEmpty) 'DOB ${patient.dob}',
      if (patient.gender != null) patient.gender!.name,
      if (patient.relationship != null) patient.relationship!.name,
      if ((patient.contactDisplayName ?? '').trim().isNotEmpty)
        patient.contactDisplayName!,
    ];

    return parts.where((p) => p.trim().isNotEmpty).join(' · ');
  }
}

class _MembershipTab extends StatelessWidget {
  const _MembershipTab({
    required this.searchCtl,
    required this.memberships,
    required this.error,
    required this.selectedMembershipId,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSelect,
    required this.subtitleBuilder,
  });

  final TextEditingController searchCtl;
  final List<InsuranceMembership> memberships;
  final String? error;
  final String? selectedMembershipId;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<InsuranceMembership> onSelect;
  final String Function(InsuranceMembership membership) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchBox(
          controller: searchCtl,
          label: 'Search memberships',
          hint: 'Patient, payer, member no, scheme...',
          onChanged: onSearchChanged,
          onRefresh: onRefresh,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ErrorText(error!),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: memberships.isEmpty
              ? const _EmptyText(
                  icon: Icons.verified_user_outlined,
                  text: 'No active insurance memberships found.',
                )
              : ListView.separated(
                  itemCount: memberships.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final membership = memberships[index];
                    final selected =
                        membership.membershipId.trim() ==
                        (selectedMembershipId ?? '').trim();

                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          selected
                              ? Icons.check
                              : Icons.health_and_safety_outlined,
                        ),
                      ),
                      title: Text(
                        membership.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        subtitleBuilder(membership),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FilledButton(
                        onPressed: () => onSelect(membership),
                        child: Text(selected ? 'Selected' : 'Use'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

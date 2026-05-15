// lib/core/home/widgets/activities/member_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/widgets/activities/latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/activities/patient_activity_adapter.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';

class MemberLatestActivityPanel extends ConsumerWidget {
  const MemberLatestActivityPanel({super.key, required this.contactId});

  /// Real Zoho/contact ID used by clinical patient-contact links.
  final String? contactId;

  static const int _maxItems = 8;

  String? get _cleanContactId {
    final id = contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopedContactId = _cleanContactId;

    if (scopedContactId == null) {
      return const LatestActivityPanel(
        title: 'Latest Activity',
        icon: Icons.notifications_none,
        loading: false,
        hasError: false,
        entries: <ActivityEntry>[],
        emptyText: 'No patient profiles linked to your account yet.',
        maxItems: _maxItems,
      );
    }

    final scope = PatientProfilesScope(
      contactId: scopedContactId,
      allowExplicitContactLink: false,
    );

    final state = ref.watch(patientProfilesControllerProvider(scope));

    final entries = <ActivityEntry>[
      ...PatientActivityAdapter.fromPatients(state.items),
    ];

    return LatestActivityPanel(
      title: 'Latest Activity',
      icon: Icons.notifications_none,
      loading: state.isLoading,
      hasError: state.error != null,
      errorText: state.error ?? 'Could not load activity.',
      entries: entries,
      emptyText: 'No patient profiles linked to your account yet.',
      maxItems: _maxItems,
    );
  }
}

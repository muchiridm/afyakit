// lib/features/insurance/memberships/widgets/insurance_memberships_panel.dart

import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceMembershipsPanel extends ConsumerStatefulWidget {
  const InsuranceMembershipsPanel({
    super.key,
    required this.patientId,
    this.patientDisplayName,
  });

  final String patientId;
  final String? patientDisplayName;

  @override
  ConsumerState<InsuranceMembershipsPanel> createState() =>
      _InsuranceMembershipsPanelState();
}

class _InsuranceMembershipsPanelState
    extends ConsumerState<InsuranceMembershipsPanel> {
  @override
  void initState() {
    super.initState();

    Future<void>.microtask(() {
      ref
          .read(insuranceMembershipsControllerProvider.notifier)
          .loadForPatient(widget.patientId);
    });
  }

  Future<void> _reload() {
    return ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .loadForPatient(widget.patientId);
  }

  Future<void> _openCreateDialog() async {
    final input = await showDialog<InsuranceMembershipUpsertInput>(
      context: context,
      builder: (_) => InsuranceMembershipFormDialog(
        patientId: widget.patientId,
        patientDisplayName: widget.patientDisplayName,
      ),
    );

    if (input == null || !mounted) return;

    final membership = await ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .create(input);

    if (!mounted) return;

    if (membership == null) {
      final error = ref.read(insuranceMembershipsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to create membership')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Insurance membership saved')));
  }

  Future<void> _openEditDialog(InsuranceMembership membership) async {
    final input = await showDialog<InsuranceMembershipUpsertInput>(
      context: context,
      builder: (_) => InsuranceMembershipFormDialog(
        initial: membership,
        patientId: widget.patientId,
        patientDisplayName: widget.patientDisplayName,
      ),
    );

    if (input == null || !mounted) return;

    final updated = await ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .update(membership.membershipId, input);

    if (!mounted) return;

    if (updated == null) {
      final error = ref.read(insuranceMembershipsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update membership')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Insurance membership updated')),
    );
  }

  Future<void> _deactivate(InsuranceMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate membership?'),
        content: Text(
          'This will deactivate ${membership.displayTitle}. Existing claims remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .delete(membership.membershipId);

    if (!mounted) return;

    if (!ok) {
      final error = ref.read(insuranceMembershipsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to deactivate membership')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Insurance membership deactivated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insuranceMembershipsControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Insurance memberships',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: state.isLoading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  onPressed: state.isSaving ? null : _openCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add membership'),
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.items.isEmpty)
              const Text('No active insurance memberships recorded.')
            else
              ...state.items.map(
                (membership) => _InsuranceMembershipTile(
                  membership: membership,
                  onEdit: () => _openEditDialog(membership),
                  onDeactivate: () => _deactivate(membership),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceMembershipTile extends StatelessWidget {
  const _InsuranceMembershipTile({
    required this.membership,
    required this.onEdit,
    required this.onDeactivate,
  });

  final InsuranceMembership membership;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      membership.payerLabel,
      if ((membership.scheme ?? '').trim().isNotEmpty)
        membership.scheme!.trim(),
      if ((membership.policyNumber ?? '').trim().isNotEmpty)
        'Policy: ${membership.policyNumber!.trim()}',
    ];

    return Card.outlined(
      child: ListTile(
        title: Text(membership.displayTitle),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'Deactivate',
              onPressed: onDeactivate,
              icon: const Icon(Icons.block),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/features/insurance/memberships/widgets/insurance_membership_picker.dart

import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceMembershipPickerCard extends ConsumerStatefulWidget {
  const InsuranceMembershipPickerCard({
    super.key,
    this.initialMembershipId,
    this.patientId,
    this.allowedPatientIds,
    this.title = 'Insurance membership',
    this.emptyText,
    this.onSelected,
  });

  final String? initialMembershipId;

  /// Optional hard filter. Useful after a patient has already been selected.
  final String? patientId;

  /// Optional local visibility guard.
  ///
  /// In member-scoped flows, pass the linked patient IDs here so the picker
  /// never displays memberships belonging to unrelated patients, even if the
  /// controller state contains broader data.
  final Set<String>? allowedPatientIds;

  final String title;
  final String? emptyText;
  final ValueChanged<InsuranceMembership>? onSelected;

  @override
  ConsumerState<InsuranceMembershipPickerCard> createState() =>
      _InsuranceMembershipPickerCardState();
}

class _InsuranceMembershipPickerCardState
    extends ConsumerState<InsuranceMembershipPickerCard> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant InsuranceMembershipPickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String oldPatientId = _clean(oldWidget.patientId);
    final String nextPatientId = _clean(widget.patientId);

    if (oldPatientId != nextPatientId) {
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final String patientId = _clean(widget.patientId);

    return ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .load(
          patientId: patientId.isEmpty ? null : patientId,
          isActive: true,
          perPage: 200,
          page: 1,
        );
  }

  String _clean(String? value) => (value ?? '').trim();

  bool _contains(String source, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return source.toLowerCase().contains(q);
  }

  bool _isAllowed(InsuranceMembership membership) {
    final Set<String>? allowed = widget.allowedPatientIds;

    // null means "no local restriction".
    if (allowed == null) return true;

    // Empty set means "explicitly allow nobody".
    // This is important for member-scoped flows while linked profiles are
    // unavailable or not loaded.
    if (allowed.isEmpty) return false;

    return allowed.contains(membership.patientId.trim());
  }

  List<InsuranceMembership> _filtered(List<InsuranceMembership> items) {
    final String q = _searchCtl.text.trim();

    return items
        .where((InsuranceMembership membership) {
          if (!membership.isActive) return false;
          if (!_isAllowed(membership)) return false;

          final String haystack = <String?>[
            membership.membershipId,
            membership.patientId,
            membership.patientNo,
            membership.patientDisplayName,
            membership.payerDisplayName,
            membership.payerAccountNumber,
            membership.memberNo,
            membership.memberName,
            membership.principalName,
            membership.scheme,
            membership.medicalCardNo,
            membership.policyNo,
            membership.providerName,
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  void _select(InsuranceMembership membership) {
    widget.onSelected?.call(membership);
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceMembershipsState state = ref.watch(
      insuranceMembershipsControllerProvider,
    );

    final List<InsuranceMembership> memberships = _filtered(state.items);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: widget.title,
              count: memberships.length,
              isLoading: state.isLoading,
              onRefresh: _load,
            ),
            const SizedBox(height: 12),
            _SearchBox(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              onRefresh: _load,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorText(state.error!),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading && memberships.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : memberships.isEmpty
                  ? _EmptyText(
                      text:
                          widget.emptyText ??
                          'No active insurance memberships found.',
                    )
                  : ListView.separated(
                      itemCount: memberships.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final InsuranceMembership membership =
                            memberships[index];

                        final bool selected =
                            membership.membershipId.trim() ==
                            _clean(widget.initialMembershipId);

                        return _MembershipTile(
                          membership: membership,
                          selected: selected,
                          onTap: () => _select(membership),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class InsuranceMembershipPickerDialog extends StatelessWidget {
  const InsuranceMembershipPickerDialog({
    super.key,
    this.initialMembershipId,
    this.patientId,
    this.allowedPatientIds,
    this.title = 'Select insurance membership',
    this.emptyText,
  });

  final String? initialMembershipId;
  final String? patientId;
  final Set<String>? allowedPatientIds;
  final String title;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 720,
        height: MediaQuery.of(context).size.height * 0.72,
        child: InsuranceMembershipPickerCard(
          initialMembershipId: initialMembershipId,
          patientId: patientId,
          allowedPatientIds: allowedPatientIds,
          emptyText: emptyText,
          onSelected: (InsuranceMembership membership) {
            Navigator.of(context).pop(membership);
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.isLoading,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const CircleAvatar(child: Icon(Icons.health_and_safety_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                count == 1
                    ? '1 membership available.'
                    : '$count memberships available.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh memberships',
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Search memberships',
        hintText: 'Patient, payer, member no, scheme...',
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

class _MembershipTile extends StatelessWidget {
  const _MembershipTile({
    required this.membership,
    required this.selected,
    required this.onTap,
  });

  final InsuranceMembership membership;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(selected ? Icons.check : Icons.health_and_safety_outlined),
      ),
      title: Text(
        membership.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _subtitle(membership),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton(
        onPressed: onTap,
        child: Text(selected ? 'Selected' : 'Use'),
      ),
      onTap: onTap,
    );
  }

  static String _subtitle(InsuranceMembership membership) {
    final List<String> parts = <String>[
      membership.payerLabel,
      if (_clean(membership.scheme).isNotEmpty) membership.scheme!,
      if (_clean(membership.memberNo).isNotEmpty)
        'Member ${membership.memberNo}',
      if (_clean(membership.policyNo).isNotEmpty)
        'Policy ${membership.policyNo}',
      if (_clean(membership.medicalCardNo).isNotEmpty)
        'Card ${membership.medicalCardNo}',
      if (_clean(membership.providerName).isNotEmpty) membership.providerName!,
    ];

    return parts.where((String p) => p.trim().isNotEmpty).join(' · ');
  }

  static String _clean(String? value) => (value ?? '').trim();
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
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.verified_user_outlined, size: 42),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

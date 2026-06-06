// lib/features/insurance/claims/widgets/insurance_claim_picker.dart

import 'package:afyakit/features/insurance/claims/controllers/insurance_claims_controller.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceClaimPickerCard extends ConsumerStatefulWidget {
  const InsuranceClaimPickerCard({
    super.key,
    this.initialClaimId,
    this.patientId,
    this.membershipId,
    this.invoiceId,
    this.allowedPatientIds,
    this.title = 'Insurance claim',
    this.emptyText,
    this.onSelected,
  });

  final String? initialClaimId;

  /// Optional hard filters.
  final String? patientId;
  final String? membershipId;
  final String? invoiceId;

  /// Optional local visibility guard.
  final Set<String>? allowedPatientIds;

  final String title;
  final String? emptyText;
  final ValueChanged<InsuranceClaim>? onSelected;

  @override
  ConsumerState<InsuranceClaimPickerCard> createState() =>
      _InsuranceClaimPickerCardState();
}

class _InsuranceClaimPickerCardState
    extends ConsumerState<InsuranceClaimPickerCard> {
  final TextEditingController _searchCtl = TextEditingController();

  String? _selectedClaimId;

  @override
  void initState() {
    super.initState();

    _selectedClaimId = _cleanOrNull(widget.initialClaimId);

    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant InsuranceClaimPickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String oldPatientId = _clean(oldWidget.patientId);
    final String nextPatientId = _clean(widget.patientId);

    final String oldMembershipId = _clean(oldWidget.membershipId);
    final String nextMembershipId = _clean(widget.membershipId);

    final String oldInvoiceId = _clean(oldWidget.invoiceId);
    final String nextInvoiceId = _clean(widget.invoiceId);

    final String? oldInitialId = _cleanOrNull(oldWidget.initialClaimId);
    final String? nextInitialId = _cleanOrNull(widget.initialClaimId);

    if (oldInitialId != nextInitialId && nextInitialId != _selectedClaimId) {
      _selectedClaimId = nextInitialId;
    }

    final bool filterChanged =
        oldPatientId != nextPatientId ||
        oldMembershipId != nextMembershipId ||
        oldInvoiceId != nextInvoiceId;

    if (filterChanged) {
      _selectedClaimId = nextInitialId;
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final String? patientId = _cleanOrNull(widget.patientId);
    final InsuranceClaimsController controller = ref.read(
      insuranceClaimsControllerProvider.notifier,
    );

    if (patientId != null) {
      return controller.loadForPatient(
        patientId: patientId,
        membershipId: _cleanOrNull(widget.membershipId),
        invoiceId: _cleanOrNull(widget.invoiceId),
        isActive: true,
        perPage: 100,
        page: 1,
      );
    }

    return controller.load(
      membershipId: _cleanOrNull(widget.membershipId),
      invoiceId: _cleanOrNull(widget.invoiceId),
      isActive: true,
      perPage: 100,
      page: 1,
    );
  }

  String _clean(String? value) => (value ?? '').trim();

  String? _cleanOrNull(String? value) {
    final String clean = _clean(value);
    return clean.isEmpty ? null : clean;
  }

  bool _contains(String source, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return source.toLowerCase().contains(q);
  }

  bool _isAllowed(InsuranceClaim claim) {
    final Set<String>? allowed = widget.allowedPatientIds;

    if (allowed == null) return true;
    if (allowed.isEmpty) return false;

    return allowed.contains(claim.patientId.trim());
  }

  List<InsuranceClaim> _filtered(List<InsuranceClaim> items) {
    final String q = _searchCtl.text.trim();

    return items
        .where((InsuranceClaim claim) {
          if (!claim.isActive) return false;
          if (!_isAllowed(claim)) return false;

          final String patientId = _clean(widget.patientId);
          final String membershipId = _clean(widget.membershipId);
          final String invoiceId = _clean(widget.invoiceId);

          if (patientId.isNotEmpty && claim.patientId.trim() != patientId) {
            return false;
          }

          if (membershipId.isNotEmpty &&
              claim.membershipId.trim() != membershipId) {
            return false;
          }

          if (invoiceId.isNotEmpty &&
              (claim.invoiceId ?? '').trim() != invoiceId) {
            return false;
          }

          final String haystack = <String?>[
            claim.claimId,
            claim.patientId,
            claim.patientNo,
            claim.patientDisplayName,
            claim.invoiceId,
            claim.invoiceNumber,
            claim.payerContactId,
            claim.payerDisplayName,
            claim.memberNo,
            claim.memberName,
            claim.principalName,
            claim.scheme,
            claim.medicalCardNo,
            claim.policyNo,
            claim.authCode,
            claim.claimNo,
            claim.visitNo,
            claim.serviceDate,
            claim.prescriptionNo,
            claim.prescriptionId,
            claim.diagnosis,
            claim.icd10Code,
            claim.fileName,
            claim.status.label,
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  void _select(InsuranceClaim claim) {
    final String claimId = claim.claimId.trim();
    if (claimId.isEmpty) return;

    setState(() {
      _selectedClaimId = claimId;
    });

    widget.onSelected?.call(claim);
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceClaimsState state = ref.watch(
      insuranceClaimsControllerProvider,
    );
    final List<InsuranceClaim> claims = _filtered(state.items);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: widget.title,
              count: claims.length,
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
              child: state.isLoading && claims.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : claims.isEmpty
                  ? _EmptyText(
                      text:
                          widget.emptyText ??
                          'No active insurance claims found.',
                    )
                  : ListView.separated(
                      itemCount: claims.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final InsuranceClaim claim = claims[index];

                        final bool selected =
                            claim.claimId.trim() == _clean(_selectedClaimId);

                        return _ClaimTile(
                          claim: claim,
                          selected: selected,
                          onTap: () => _select(claim),
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

class InsuranceClaimPickerDialog extends StatelessWidget {
  const InsuranceClaimPickerDialog({
    super.key,
    this.initialClaimId,
    this.patientId,
    this.membershipId,
    this.invoiceId,
    this.allowedPatientIds,
    this.title = 'Select insurance claim',
    this.emptyText,
  });

  final String? initialClaimId;
  final String? patientId;
  final String? membershipId;
  final String? invoiceId;
  final Set<String>? allowedPatientIds;
  final String title;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: InsuranceClaimPickerCard(
          initialClaimId: initialClaimId,
          patientId: patientId,
          membershipId: membershipId,
          invoiceId: invoiceId,
          allowedPatientIds: allowedPatientIds,
          emptyText: emptyText,
          onSelected: (InsuranceClaim claim) {
            Navigator.of(context).pop(claim);
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
        const CircleAvatar(child: Icon(Icons.assignment_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                count == 1 ? '1 claim available.' : '$count claims available.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh claims',
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
        labelText: 'Search claims',
        hintText: 'Patient, invoice, member no, claim no, auth...',
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

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({
    required this.claim,
    required this.selected,
    required this.onTap,
  });

  final InsuranceClaim claim;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
      leading: CircleAvatar(
        backgroundColor: selected ? scheme.primaryContainer : null,
        foregroundColor: selected ? scheme.onPrimaryContainer : null,
        child: Icon(selected ? Icons.check : Icons.assignment_outlined),
      ),
      title: Text(_title(claim), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _subtitle(claim),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _DocumentStatusIcon(claim: claim),
          FilledButton(
            onPressed: onTap,
            child: Text(selected ? 'Selected' : 'Use'),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static String _title(InsuranceClaim claim) {
    final String patient = _clean(claim.patientDisplayName) ?? claim.patientId;
    final String invoice =
        _clean(claim.invoiceNumber) ?? _clean(claim.invoiceId) ?? claim.claimId;

    return '$patient · $invoice';
  }

  static String _subtitle(InsuranceClaim claim) {
    final List<String> parts = <String>[
      claim.status.label,
      if (_clean(claim.payerDisplayName) != null) claim.payerDisplayName!,
      if (_clean(claim.memberNo) != null) 'Member ${claim.memberNo}',
      if (_clean(claim.scheme) != null) claim.scheme!,
      if (_clean(claim.claimNo) != null) 'Claim ${claim.claimNo}',
      if (_clean(claim.authCode) != null) 'Auth ${claim.authCode}',
      if (_clean(claim.prescriptionId) != null) 'Rx linked',
      if (claim.hasFile) 'Document uploaded',
    ];

    return parts.join(' · ');
  }

  static String? _clean(String? value) {
    final String s = (value ?? '').trim();
    return s.isEmpty ? null : s;
  }
}

class _DocumentStatusIcon extends StatelessWidget {
  const _DocumentStatusIcon({required this.claim});

  final InsuranceClaim claim;

  @override
  Widget build(BuildContext context) {
    if (claim.hasFile) {
      return const Tooltip(
        message: 'Claim document uploaded',
        child: Icon(Icons.verified_outlined),
      );
    }

    return const Tooltip(
      message: 'Claim document missing',
      child: Icon(Icons.pending_actions_outlined),
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
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.assignment_outlined, size: 42),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

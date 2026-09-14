import 'package:afyakit/features/insurance/claim_packs/controllers/insurance_claim_packs_controller.dart';
import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:afyakit/shared/widgets/entity_picker_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceClaimPickerCard extends ConsumerStatefulWidget {
  const InsuranceClaimPickerCard({
    super.key,
    this.initialClaimPackId,
    this.patientId,
    this.membershipId,
    this.invoiceId,
    this.allowedPatientIds,
    this.title = 'Insurance claim pack',
    this.emptyText,
    this.onSelected,
  });

  final String? initialClaimPackId;

  /// Optional hard filters.
  final String? patientId;
  final String? membershipId;
  final String? invoiceId;

  /// Optional local visibility guard.
  final Set<String>? allowedPatientIds;

  final String title;
  final String? emptyText;
  final ValueChanged<InsuranceClaimPack>? onSelected;

  @override
  ConsumerState<InsuranceClaimPickerCard> createState() =>
      _InsuranceClaimPickerCardState();
}

class _InsuranceClaimPickerCardState
    extends ConsumerState<InsuranceClaimPickerCard> {
  final TextEditingController _searchCtl = TextEditingController();

  String? _selectedClaimPackId;

  @override
  void initState() {
    super.initState();

    _selectedClaimPackId = _cleanOrNull(widget.initialClaimPackId);

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

    final String? oldInitialId = _cleanOrNull(oldWidget.initialClaimPackId);
    final String? nextInitialId = _cleanOrNull(widget.initialClaimPackId);

    if (oldInitialId != nextInitialId &&
        nextInitialId != _selectedClaimPackId) {
      _selectedClaimPackId = nextInitialId;
    }

    final bool filterChanged =
        oldPatientId != nextPatientId ||
        oldMembershipId != nextMembershipId ||
        oldInvoiceId != nextInvoiceId;

    if (filterChanged) {
      _selectedClaimPackId = nextInitialId;
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

    final InsuranceClaimPacksController controller = ref.read(
      insuranceClaimPacksControllerProvider.notifier,
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

  bool _isAllowed(InsuranceClaimPack pack) {
    final Set<String>? allowed = widget.allowedPatientIds;

    if (allowed == null) return true;
    if (allowed.isEmpty) return false;

    return allowed.contains(pack.patientId.trim());
  }

  List<InsuranceClaimPack> _filtered(List<InsuranceClaimPack> items) {
    final String q = _searchCtl.text.trim();

    return items
        .where((InsuranceClaimPack pack) {
          if (!pack.isActive) return false;
          if (!_isAllowed(pack)) return false;

          final String patientId = _clean(widget.patientId);
          final String membershipId = _clean(widget.membershipId);
          final String invoiceId = _clean(widget.invoiceId);

          if (patientId.isNotEmpty && pack.patientId.trim() != patientId) {
            return false;
          }

          if (membershipId.isNotEmpty &&
              pack.membershipId.trim() != membershipId) {
            return false;
          }

          if (invoiceId.isNotEmpty &&
              (pack.invoiceId ?? '').trim() != invoiceId) {
            return false;
          }

          final String haystack = <String?>[
            pack.claimPackId,
            pack.patientId,
            pack.patientNo,
            pack.patientDisplayName,
            pack.invoiceId,
            pack.invoiceNumber,
            pack.payerContactId,
            pack.payerDisplayName,
            pack.memberNo,
            pack.memberName,
            pack.principalName,
            pack.scheme,
            pack.medicalCardNo,
            pack.policyNo,
            pack.authCode,
            pack.insurerClaimNo,
            pack.visitNo,
            pack.serviceDate,
            pack.prescriptionNo,
            pack.prescriptionId,
            pack.diagnosis,
            pack.icd10Code,
            pack.status.label,
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  void _select(InsuranceClaimPack pack) {
    final String claimPackId = pack.claimPackId.trim();
    if (claimPackId.isEmpty) return;

    setState(() {
      _selectedClaimPackId = claimPackId;
    });

    widget.onSelected?.call(pack);
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceClaimPacksState state = ref.watch(
      insuranceClaimPacksControllerProvider,
    );

    final List<InsuranceClaimPack> claimPacks = _filtered(state.items);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PickerHeader(
              icon: Icons.assignment_outlined,
              title: widget.title,
              count: claimPacks.length,
              singularLabel: 'claim pack',
              pluralLabel: 'claim packs',
              isLoading: state.isLoading,
              onRefresh: _load,
            ),
            const SizedBox(height: 12),
            PickerSearchField(
              controller: _searchCtl,
              labelText: 'Search claim packs',
              hintText: 'Patient, invoice, member no, claim no, auth...',
              onChanged: (_) => setState(() {}),
              onAction: _load,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 8),
              PickerErrorText(state.error!),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: PickerBody<InsuranceClaimPack>(
                items: claimPacks,
                isLoading: state.isLoading,
                emptyText: widget.emptyText ?? 'No active claim packs found.',
                emptyIcon: Icons.assignment_outlined,
                itemBuilder: (BuildContext context, InsuranceClaimPack pack) {
                  final bool selected =
                      pack.claimPackId.trim() == _clean(_selectedClaimPackId);

                  return _ClaimPackTile(
                    pack: pack,
                    selected: selected,
                    onTap: () => _select(pack),
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
    this.initialClaimPackId,
    this.patientId,
    this.membershipId,
    this.invoiceId,
    this.allowedPatientIds,
    this.title = 'Select claim pack',
    this.emptyText,
  });

  final String? initialClaimPackId;
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
          initialClaimPackId: initialClaimPackId,
          patientId: patientId,
          membershipId: membershipId,
          invoiceId: invoiceId,
          allowedPatientIds: allowedPatientIds,
          emptyText: emptyText,
          onSelected: (InsuranceClaimPack pack) {
            Navigator.of(context).pop(pack);
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

class _ClaimPackTile extends StatelessWidget {
  const _ClaimPackTile({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final InsuranceClaimPack pack;
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
      title: Text(_title(pack), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _subtitle(pack),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton(
        onPressed: onTap,
        child: Text(selected ? 'Selected' : 'Use'),
      ),
      onTap: onTap,
    );
  }

  static String _title(InsuranceClaimPack pack) {
    final String patient = _clean(pack.patientDisplayName) ?? pack.patientId;

    final String ref =
        _clean(pack.invoiceNumber) ??
        _clean(pack.invoiceId) ??
        _clean(pack.insurerClaimNo) ??
        pack.claimPackId;

    return '$patient · $ref';
  }

  static String _subtitle(InsuranceClaimPack pack) {
    final List<String> parts = <String>[
      pack.status.label,
      if (_clean(pack.payerDisplayName) != null) pack.payerDisplayName!,
      if (_clean(pack.memberNo) != null) 'Member ${pack.memberNo}',
      if (_clean(pack.scheme) != null) pack.scheme!,
      if (_clean(pack.insurerClaimNo) != null) 'Claim ${pack.insurerClaimNo}',
      if (_clean(pack.authCode) != null) 'Auth ${pack.authCode}',
      if (_clean(pack.prescriptionId) != null) 'Rx linked',
      if (pack.hasInvoice) 'Invoice linked',
    ];

    return parts.join(' · ');
  }

  static String? _clean(String? value) {
    final String s = (value ?? '').trim();
    return s.isEmpty ? null : s;
  }
}

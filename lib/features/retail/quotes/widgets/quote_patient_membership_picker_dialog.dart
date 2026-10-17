// lib/features/retail/quotes/widgets/quote_patient_membership_picker_dialog.dart
import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_picker.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_picker.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/member_native_contact_provider.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuotePatientContextSelection {
  const QuotePatientContextSelection({
    required this.patientSnapshot,
    this.paymentContext = QuotePaymentContext.directPay,
    this.membershipId,
    this.payerContact,
  });
  final SalesDocumentPatientSnapshot patientSnapshot;

  /// Direct-pay means the selected quote customer/contact pays.
  /// Insurance means the payerContact should become the quote customer.
  final QuotePaymentContext paymentContext;
  final String? membershipId;

  /// Present only when the selected context came from an insurance membership.
  ///
  /// Insurance quotes must be billed to the payer/insurer, not the patient.
  final NativeContact? payerContact;
  bool get isInsurance => paymentContext == QuotePaymentContext.insurance;
  bool get hasMembership => (membershipId ?? '').trim().isNotEmpty;
  bool get hasPayerContact =>
      (payerContact?.accountNumber ?? '').trim().isNotEmpty;
}

class QuotePatientMembershipPickerDialog extends ConsumerStatefulWidget {
  const QuotePatientMembershipPickerDialog({
    super.key,
    this.initialProfileId,
    this.initialMembershipId,
    this.initialPaymentContext = QuotePaymentContext.directPay,
  });
  final String? initialProfileId;
  final String? initialMembershipId;
  final QuotePaymentContext initialPaymentContext;
  @override
  ConsumerState<QuotePatientMembershipPickerDialog> createState() =>
      _QuotePatientMembershipPickerDialogState();
}

class _QuotePatientMembershipPickerDialogState
    extends ConsumerState<QuotePatientMembershipPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtl;
  Profile? _selectedPatient;
  QuoteContactPolicy get _policy => ref.read(quoteContactPolicyProvider);
  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;
  String get _memberAccountNumber {
    return (ref.read(currentMemberAccountNumberProvider) ?? '').trim();
  }

  ProfilesScope get _memberProfileScope {
    final accountNumber = _memberAccountNumber.trim();

    return ProfilesScope(
      accountNumber: accountNumber.isEmpty ? null : accountNumber,
      memberMode: true,
      allowExplicitContactLink: false,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 2, vsync: this);
    final bool openInsurance =
        widget.initialPaymentContext == QuotePaymentContext.insurance ||
        (widget.initialMembershipId ?? '').trim().isNotEmpty;
    if (openInsurance) _tabCtl.index = 1;
    final String initialProfileId = _clean(widget.initialProfileId);
    if (initialProfileId.isNotEmpty) {
      _selectedPatient = Profile(
        profileId: initialProfileId,
        fullName: initialProfileId,
        isActive: true,
      );
    }
    if (_isMemberScoped) {
      Future<void>.microtask(_loadLinkedProfilesForMembershipGuard);
    }
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedProfilesForMembershipGuard() async {
    final controller = ref.read(
      profilesControllerProvider(_memberProfileScope).notifier,
    );
    controller.setIsActive(true);
    await controller.load();
  }

  String _clean(String? value) => (value ?? '').trim();
  Set<String>? _allowedProfileIdsForMemberships() {
    if (!_isMemberScoped) return null;
    final state = ref.watch(profilesControllerProvider(_memberProfileScope));
    return state.items
        .where((Profile p) => p.isActive)
        .map((Profile p) => p.profileId.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  QuotePatientContextSelection _selectionFromPatient(Profile patient) {
    final String? gender = patient.gender?.name;
    final String? relationship = patient.relationship?.name;
    return QuotePatientContextSelection(
      paymentContext: QuotePaymentContext.directPay,
      patientSnapshot: SalesDocumentPatientSnapshot(
        profileId: patient.profileId,
        patientNo: null,
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
    final String patientName = _clean(membership.profileDisplayName).isNotEmpty
        ? membership.profileDisplayName!.trim()
        : membership.profileId.trim();
    final String payerDisplayName =
        _clean(membership.payerDisplayName).isNotEmpty
        ? membership.payerDisplayName!.trim()
        : membership.payerContactId.trim();
    final String payerAccountNumber = _clean(
      membership.payerAccountNumber,
    ).toUpperCase();
    if (payerAccountNumber.isEmpty) {
      throw StateError('Insurance payer has no Native Contact account number.');
    }
    // This is a UI-only contact selection. The backend must independently
    // verify the insurer and resolve its accounting projection.
    final NativeContact payerContact = NativeContact(
      accountNumber: payerAccountNumber,
      displayName: payerDisplayName,
      entityType: 'organization',
      contactType: 'customer',
      status: 'active',
      appIds: const <String>[],
      isInsurancePayer: true,
    );
    return QuotePatientContextSelection(
      paymentContext: QuotePaymentContext.insurance,
      membershipId: membership.membershipId,
      payerContact: payerContact,
      patientSnapshot: SalesDocumentPatientSnapshot(
        profileId: membership.profileId,
        patientNo: membership.patientNo,
        fullName: patientName,
        membershipId: membership.membershipId,
        memberNo: membership.memberNo,
        scheme: membership.scheme,
        payerName: payerDisplayName,
      ),
    );
  }

  void _selectPatient(Profile patient) {
    Navigator.of(context).pop(_selectionFromPatient(patient));
  }

  void _selectMembership(InsuranceMembership membership) {
    try {
      final selection = _selectionFromMembership(membership);
      Navigator.of(context).pop(selection);
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<String>? allowedProfileIds = _allowedProfileIdsForMemberships();
    final bool memberContactMissing =
        _isMemberScoped && _memberAccountNumber.isEmpty;
    return AlertDialog(
      title: Text(
        _isMemberScoped
            ? 'Select your patient / insurance'
            : 'Select patient / insurance',
      ),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: <Widget>[
            if (memberContactMissing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _ErrorText(
                  'Your customer profile is not linked yet. Please refresh or contact support.',
                ),
              ),
            TabBar(
              controller: _tabCtl,
              tabs: const <Widget>[
                Tab(icon: Icon(Icons.person_outline), text: 'Direct pay'),
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
                children: <Widget>[
                  _DirectPayPatientTab(
                    memberScoped: _isMemberScoped,
                    accountNumber: _isMemberScoped
                        ? _memberAccountNumber
                        : null,
                    selectedPatient: _selectedPatient,
                    onSelected: (Profile patient) {
                      setState(() => _selectedPatient = patient);
                      _selectPatient(patient);
                    },
                  ),
                  _InsuranceMembershipTab(
                    memberScoped: _isMemberScoped,
                    initialMembershipId: widget.initialMembershipId,
                    allowedProfileIds: allowedProfileIds,
                    onSelected: _selectMembership,
                  ),
                ],
              ),
            ),
          ],
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

class _DirectPayPatientTab extends StatelessWidget {
  const _DirectPayPatientTab({
    required this.memberScoped,
    required this.accountNumber,
    required this.selectedPatient,
    required this.onSelected,
  });
  final bool memberScoped;
  final String? accountNumber;
  final Profile? selectedPatient;
  final ValueChanged<Profile> onSelected;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _TabHint(
          icon: Icons.payments_outlined,
          text: memberScoped
              ? 'Choose one of your linked patient profiles for direct-pay orders.'
              : 'Choose the patient receiving care or medicine. The selected quote customer remains the payer.',
        ),
        const SizedBox(height: 12),
        ProfilePickerCard(
          selectedProfile: selectedPatient,
          busy: false,
          accountNumber: memberScoped ? accountNumber?.trim() : null,
          forcePickerMode: !memberScoped,
          onChanged: onSelected,
        ),
        const Spacer(),
      ],
    );
  }
}

class _InsuranceMembershipTab extends StatelessWidget {
  const _InsuranceMembershipTab({
    required this.memberScoped,
    required this.initialMembershipId,
    required this.allowedProfileIds,
    required this.onSelected,
  });
  final bool memberScoped;
  final String? initialMembershipId;
  final Set<String>? allowedProfileIds;
  final ValueChanged<InsuranceMembership> onSelected;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _TabHint(
          icon: Icons.health_and_safety_outlined,
          text: memberScoped
              ? 'Choose insurance cover linked to your patient profiles.'
              : 'Choose this only when the insurer is paying. The quote customer will become the insurance payer.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: InsuranceMembershipPickerCard(
            initialMembershipId: initialMembershipId,
            allowedProfileIds: allowedProfileIds,
            title: memberScoped
                ? 'Your insurance memberships'
                : 'Insurance memberships',
            emptyText: memberScoped
                ? 'No insurance memberships found for your linked profiles.'
                : 'No active insurance memberships found.',
            onSelected: onSelected,
          ),
        ),
      ],
    );
  }
}

class _TabHint extends StatelessWidget {
  const _TabHint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
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

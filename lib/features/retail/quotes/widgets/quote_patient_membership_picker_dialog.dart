// lib/features/retail/quotes/widgets/quote_patient_membership_picker_dialog.dart

import 'package:afyakit/features/clinical/profiles/controllers/profiles_controller.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_picker.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_picker.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
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
  final ZohoContact? payerContact;

  bool get isInsurance => paymentContext == QuotePaymentContext.insurance;

  bool get hasMembership => (membershipId ?? '').trim().isNotEmpty;

  bool get hasPayerContact => (payerContact?.contactId ?? '').trim().isNotEmpty;
}

class QuotePatientMembershipPickerDialog extends ConsumerStatefulWidget {
  const QuotePatientMembershipPickerDialog({
    super.key,
    this.initialPatientId,
    this.initialMembershipId,
    this.initialPaymentContext = QuotePaymentContext.directPay,
  });

  final String? initialPatientId;
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

  static const String _missingMemberContactId = '__missing_member_contact__';

  Profile? _selectedPatient;

  QuoteContactPolicy get _policy => ref.read(quoteContactPolicyProvider);

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;

  String get _memberContactId {
    return (ref.read(zohoMemberCustomerScopeProvider)?.contactId ?? '').trim();
  }

  ProfilesScope get _memberPatientScope {
    final String contactId = _memberContactId;

    return ProfilesScope(
      contactId: contactId.isEmpty ? _missingMemberContactId : contactId,
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

    if (_isMemberScoped) {
      Future<void>.microtask(_loadLinkedPatientsForMembershipGuard);
    }
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedPatientsForMembershipGuard() async {
    final controller = ref.read(
      profilesControllerProvider(_memberPatientScope).notifier,
    );

    controller.setIsActive(true);
    await controller.load();
  }

  String _clean(String? value) => (value ?? '').trim();

  Set<String>? _allowedPatientIdsForMemberships() {
    if (!_isMemberScoped) return null;

    final state = ref.watch(profilesControllerProvider(_memberPatientScope));

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
        patientId: patient.profileId,
        patientNo: patient.profileId,
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
    final String patientName = _clean(membership.patientDisplayName).isNotEmpty
        ? membership.patientDisplayName!.trim()
        : membership.patientId.trim();

    final String payerDisplayName =
        _clean(membership.payerDisplayName).isNotEmpty
        ? membership.payerDisplayName!.trim()
        : membership.payerContactId.trim();

    final ZohoContact payerContact = ZohoContact(
      contactId: membership.payerContactId.trim(),
      displayName: payerDisplayName,
      accountNumber: _clean(membership.payerAccountNumber).isEmpty
          ? null
          : membership.payerAccountNumber!.trim(),
      contactType: 'customer',
      isInsurancePayer: true,
    );

    return QuotePatientContextSelection(
      paymentContext: QuotePaymentContext.insurance,
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

  void _selectPatient(Profile patient) {
    Navigator.of(context).pop(_selectionFromPatient(patient));
  }

  void _selectMembership(InsuranceMembership membership) {
    Navigator.of(context).pop(_selectionFromMembership(membership));
  }

  @override
  Widget build(BuildContext context) {
    final Set<String>? allowedPatientIds = _allowedPatientIdsForMemberships();

    final bool memberContactMissing =
        _isMemberScoped && _memberContactId.isEmpty;

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
                    contactId: _isMemberScoped ? _memberContactId : null,
                    selectedPatient: _selectedPatient,
                    onSelected: (Profile patient) {
                      setState(() => _selectedPatient = patient);
                      _selectPatient(patient);
                    },
                  ),
                  _InsuranceMembershipTab(
                    memberScoped: _isMemberScoped,
                    initialMembershipId: widget.initialMembershipId,
                    allowedPatientIds: allowedPatientIds,
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
    required this.contactId,
    required this.selectedPatient,
    required this.onSelected,
  });

  final bool memberScoped;
  final String? contactId;
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
          contactId: memberScoped ? contactId : null,
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
    required this.allowedPatientIds,
    required this.onSelected,
  });

  final bool memberScoped;
  final String? initialMembershipId;
  final Set<String>? allowedPatientIds;
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
            allowedPatientIds: allowedPatientIds,
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

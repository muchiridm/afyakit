// lib/features/retail/quotes/widgets/quote_editor_details_sheet.dart

import 'package:afyakit/features/clinical/profiles/controllers/profiles_controller.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_picker.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescription_picker.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address_scope.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_picker.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/controllers/states/quote_meta_state.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:afyakit/shared/widgets/app_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_editor_details_components.dart';

class QuoteEditorDetailsSheet extends ConsumerStatefulWidget {
  const QuoteEditorDetailsSheet({
    super.key,
    required this.initial,
    required this.tenantId,
    required this.isStaffMode,
    required this.onEnsureAuthed,
  });

  final QuoteMetaState initial;
  final String tenantId;
  final bool isStaffMode;
  final Future<bool> Function() onEnsureAuthed;

  static Future<QuoteMetaState?> open(
    BuildContext context, {
    required QuoteMetaState initial,
    required String tenantId,
    required bool isStaffMode,
    required Future<bool> Function() onEnsureAuthed,
  }) {
    return showAppBottomSheet<QuoteMetaState>(
      context: context,
      maxWidth: 820,
      maxHeightFactor: 0.96,
      builder: (_) => QuoteEditorDetailsSheet(
        initial: initial,
        tenantId: tenantId,
        isStaffMode: isStaffMode,
        onEnsureAuthed: onEnsureAuthed,
      ),
    );
  }

  @override
  ConsumerState<QuoteEditorDetailsSheet> createState() =>
      _QuoteEditorDetailsSheetState();
}

class _QuoteEditorDetailsSheetState
    extends ConsumerState<QuoteEditorDetailsSheet> {
  static const String _missingMemberContactId = '__missing_member_contact__';

  late QuoteMetaState _draft;
  late QuotePaymentContext _paymentContext;

  Profile? _profile;
  InsuranceMembership? _membership;
  Prescription? _prescription;

  bool _initialHydrationAttempted = false;
  bool _uploadingPrescription = false;

  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  bool get _isMemberScoped => !widget.isStaffMode;

  String get _memberContactId {
    return (ref.read(zohoMemberCustomerScopeProvider)?.contactId ?? '').trim();
  }

  String? get _patientId {
    return _clean(_profile?.profileId) ?? _clean(_draft.resolvedPatientId);
  }

  bool get _requiresInsurance {
    return _paymentContext == QuotePaymentContext.insurance;
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

    _draft = widget.initial;
    _paymentContext = widget.initial.effectivePaymentContext;

    final SalesDocumentPatientSnapshot? snapshot =
        widget.initial.patientSnapshot;
    final String? snapshotPatientId = _clean(snapshot?.patientId);

    if (snapshotPatientId != null) {
      _profile = Profile(
        profileId: snapshotPatientId,
        fullName: _clean(snapshot?.fullName) ?? snapshotPatientId,
        dob: _clean(snapshot?.dob),
        isActive: true,
      );
    }

    _referenceController = TextEditingController(
      text: widget.initial.reference ?? '',
    );

    _notesController = TextEditingController(
      text: widget.initial.customerNotes ?? '',
    );

    if (_isMemberScoped) {
      Future<void>.microtask(_loadLinkedProfiles);
    }

    final String? patientId = _patientId;
    if (patientId != null) {
      Future<void>.microtask(() => _loadPrescriptions(patientId));
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _patch(QuoteMetaState next) {
    if (!mounted) return;

    setState(() {
      _draft = next;
    });
  }

  Future<void> _loadLinkedProfiles() async {
    final ProfilesController controller = ref.read(
      profilesControllerProvider(_memberPatientScope).notifier,
    );

    controller.setIsActive(true);
    await controller.load();
  }

  Future<void> _loadPrescriptions(String patientId) {
    return ref
        .read(prescriptionsControllerProvider(patientId).notifier)
        .load(profileId: patientId, isActive: true);
  }

  void _hydrateInitialSelections({
    required List<InsuranceMembership> memberships,
    required List<Prescription> prescriptions,
  }) {
    if (_initialHydrationAttempted) return;

    final String? membershipId = _clean(_draft.resolvedMembershipId);
    final String? prescriptionId = _clean(_draft.resolvedPrescriptionId);

    final InsuranceMembership? membership = _findMembershipById(
      memberships,
      membershipId,
    );

    final Prescription? prescription = _findPrescriptionById(
      prescriptions,
      prescriptionId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialHydrationAttempted) return;

      setState(() {
        _initialHydrationAttempted = true;
        _membership ??= membership;
        _prescription ??= prescription;

        if (_profile == null && membership != null) {
          _profile = Profile(
            profileId: membership.patientId,
            fullName:
                _clean(membership.patientDisplayName) ?? membership.patientId,
            isActive: true,
          );
        }
      });
    });
  }

  InsuranceMembership? _findMembershipById(
    List<InsuranceMembership> memberships,
    String? membershipId,
  ) {
    final String? id = _clean(membershipId);
    if (id == null) return null;

    for (final InsuranceMembership membership in memberships) {
      if (membership.membershipId.trim() == id) return membership;
    }

    return null;
  }

  Prescription? _findPrescriptionById(
    List<Prescription> prescriptions,
    String? prescriptionId,
  ) {
    final String? id = _clean(prescriptionId);
    if (id == null) return null;

    for (final Prescription prescription in prescriptions) {
      if (prescription.prescriptionId.trim() == id) return prescription;
    }

    return null;
  }

  Profile? _findLoadedProfileById(String? patientId) {
    final String? id = _clean(patientId);
    if (id == null || !_isMemberScoped) return null;

    final ProfilesState state = ref.read(
      profilesControllerProvider(_memberPatientScope),
    );

    for (final Profile profile in state.items) {
      if (profile.profileId.trim() == id) return profile;
    }

    return null;
  }

  Set<String>? _allowedPatientIdsForMemberships() {
    if (!_isMemberScoped) return null;

    final ProfilesState state = ref.watch(
      profilesControllerProvider(_memberPatientScope),
    );

    return state.items
        .where((Profile profile) => profile.isActive)
        .map((Profile profile) => profile.profileId.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  double _membershipPickerHeight(int count) {
    if (count <= 0) return 220;
    if (count == 1) return 250;
    if (count == 2) return 320;
    return 420;
  }

  void _setPurchaseContext(QuotePurchaseContext context) {
    if (_draft.purchaseContext == context) return;

    setState(() {
      _draft = _draft.copyWith(purchaseContext: context);

      if (context == QuotePurchaseContext.company) {
        _paymentContext = QuotePaymentContext.directPay;
        _profile = null;
        _membership = null;
        _prescription = null;
      }
    });
  }

  void _setPaymentContext(QuotePaymentContext context) {
    setState(() {
      _paymentContext = context;

      if (context == QuotePaymentContext.directPay) {
        _membership = null;

        _draft = _draft.copyWith(
          paymentContext: context,
          clearMembershipId: true,
        );
      } else {
        _draft = _draft.copyWith(paymentContext: context);
      }
    });
  }

  void _setMembership(InsuranceMembership membership) {
    final Profile profile =
        _findLoadedProfileById(membership.patientId) ??
        _profile ??
        Profile(
          profileId: membership.patientId,
          fullName:
              _clean(membership.patientDisplayName) ?? membership.patientId,
          isActive: true,
        );

    setState(() {
      _paymentContext = QuotePaymentContext.insurance;
      _membership = membership;
      _profile = profile;

      _draft = _draft.copyWith(
        purchaseContext: QuotePurchaseContext.privateUse,
        paymentContext: QuotePaymentContext.insurance,
        contact: _payerContactFromMembership(membership),
        patientSnapshot: _snapshotFromMembership(membership, patient: profile),
        membershipId: membership.membershipId,
      );
    });

    _loadPrescriptions(membership.patientId);
  }

  void _setPrescription(Prescription? prescription) {
    setState(() {
      _prescription = prescription;

      final String? id = _clean(prescription?.prescriptionId);

      _draft = _draft.copyWith(
        prescriptionId: id,
        prescriptionLabel: prescription == null
            ? null
            : _prescriptionLabel(prescription),
        clearPrescriptionId: id == null,
        clearPrescriptionLabel: id == null,
      );
    });
  }

  Future<void> _uploadPrescription() async {
    final String? patientId = _patientId;

    if (patientId == null) {
      _snack('Select a profile first.');
      return;
    }

    final bool authenticated = await widget.onEnsureAuthed();
    if (!authenticated || !mounted) return;

    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;

    final PlatformFile file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      _snack('Could not read the selected file.');
      return;
    }

    setState(() => _uploadingPrescription = true);

    try {
      final provider = prescriptionsControllerProvider(patientId);
      final PrescriptionsController controller = ref.read(provider.notifier);

      await controller.upload(
        tenantId: widget.tenantId.trim(),
        patientId: patientId,
        file: PickedPrescriptionFile(
          fileName: file.name,
          extension: file.extension ?? 'jpg',
          bytes: bytes,
        ),
        note: null,
        prescribedOn: null,
      );

      if (!mounted) return;

      final PrescriptionsState state = ref.read(provider);

      if (state.error != null) {
        _snack(state.error!);
        return;
      }

      final Prescription? saved = state.items.isEmpty
          ? null
          : state.items.first;

      _setPrescription(saved);

      if (saved != null) {
        _snack('Prescription uploaded.');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPrescription = false);
      }
    }
  }

  void _setFulfilmentMethod(QuoteFulfilmentMethod method) {
    _patch(_draft.copyWith(fulfilmentMethod: method));
  }

  Future<void> _pickDeliveryLocation() async {
    final bool authenticated = await widget.onEnsureAuthed();
    if (!authenticated || !mounted) return;

    final DeliveryAddressScope? scope = _deliveryAddressScope();

    if (scope == null || !scope.isUsable) {
      _snack('Select a customer before choosing a delivery location.');
      return;
    }

    final DeliveryAddress? result = await Navigator.of(context)
        .push<DeliveryAddress>(
          MaterialPageRoute<DeliveryAddress>(
            builder: (_) =>
                DeliveryAddressesScreen(pickerMode: true, scope: scope),
          ),
        );

    if (result == null || !mounted) return;

    _patch(
      _draft.copyWith(
        fulfilmentMethod: QuoteFulfilmentMethod.delivery,
        deliveryAddress: SalesDocumentAddress.fromDeliveryAddress(result),
      ),
    );
  }

  DeliveryAddressScope? _deliveryAddressScope() {
    final String tenantId = widget.tenantId.trim();
    final String accountNumber = (_draft.contact?.accountNumber ?? '').trim();
    final String contactId = (_draft.contact?.contactId ?? '').trim();
    final String customerName = (_draft.contact?.title ?? '').trim();

    final String ownerUid = accountNumber.isNotEmpty
        ? 'acct_$accountNumber'
        : contactId.isNotEmpty
        ? 'zoho_$contactId'
        : '';

    if (tenantId.isEmpty || ownerUid.isEmpty) return null;

    return DeliveryAddressScope(
      tenantId: tenantId,
      ownerUid: ownerUid,
      ownerAccountNumber: accountNumber.isEmpty ? null : accountNumber,
      ownerLabel: customerName.isEmpty ? null : customerName,
    );
  }

  Future<void> _pickQuoteDate() async {
    final DateTime initial = _draft.quoteDate ?? _dateOnly(DateTime.now());

    final DateTime? picked = await _pickDate(
      initial: initial,
      helpText: 'Select quote date',
    );

    if (picked == null || !mounted) return;

    final DateTime expiry = _draft.expiryDate ?? _defaultExpiry(picked);

    _patch(_draft.copyWith(quoteDate: picked, expiryDate: expiry));
  }

  Future<void> _pickExpiryDate() async {
    final DateTime quoteDate = _draft.quoteDate ?? _dateOnly(DateTime.now());
    final DateTime initial = _draft.expiryDate ?? _defaultExpiry(quoteDate);

    final DateTime? picked = await _pickDate(
      initial: initial,
      firstDate: quoteDate,
      helpText: 'Select expiry date',
    );

    if (picked == null || !mounted) return;

    _patch(_draft.copyWith(expiryDate: picked));
  }

  Future<DateTime?> _pickDate({
    required DateTime initial,
    DateTime? firstDate,
    required String helpText,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: _dateOnly(initial),
      firstDate: firstDate ?? DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: helpText,
    );

    return result == null ? null : _dateOnly(result);
  }

  void _setReference(String value) {
    final String text = value.trim();

    _patch(_draft.copyWith(reference: text, clearReference: text.isEmpty));
  }

  void _setCustomerNotes(String value) {
    final String text = value.trim();

    _patch(
      _draft.copyWith(customerNotes: text, clearCustomerNotes: text.isEmpty),
    );
  }

  bool get _profileComplete {
    return _draft.isCompany || _patientId != null;
  }

  bool get _paymentComplete {
    if (_draft.isCompany) return true;
    if (!_requiresInsurance) return true;
    return _membership != null || _clean(_draft.resolvedMembershipId) != null;
  }

  bool get _hasPrescription {
    return _prescription != null ||
        _clean(_draft.resolvedPrescriptionId) != null;
  }

  bool get _prescriptionComplete {
    if (_draft.isCompany) return true;
    if (!_requiresInsurance) return true;

    return _hasPrescription;
  }

  bool get _fulfilmentComplete {
    if (_draft.fulfilmentMethod == QuoteFulfilmentMethod.pickup) return true;

    return _draft.deliveryAddress != null && _draft.deliveryAddress!.isUsable;
  }

  bool get _staffDetailsComplete {
    return _draft.quoteDate != null;
  }

  bool get _canSubmit {
    return _profileComplete &&
        _paymentComplete &&
        _prescriptionComplete &&
        _fulfilmentComplete;
  }

  void _submit() {
    if (!_canSubmit) {
      if (!_profileComplete) {
        _snack('Select who the quote is for.');
      } else if (!_paymentComplete) {
        _snack('Select an insurance membership.');
      } else if (!_prescriptionComplete) {
        _snack('Select or upload a prescription.');
      } else if (!_fulfilmentComplete) {
        _snack('Select a delivery location.');
      }
      return;
    }

    Navigator.of(context).pop(_draft);
  }

  SalesDocumentPatientSnapshot _snapshotFromProfile(Profile profile) {
    return SalesDocumentPatientSnapshot(
      patientId: profile.profileId,
      patientNo: profile.profileId,
      fullName: profile.fullName,
      dob: profile.dob,
      gender: profile.gender?.name,
      relationship: profile.relationship?.name,
    );
  }

  SalesDocumentPatientSnapshot _snapshotFromMembership(
    InsuranceMembership membership, {
    required Profile patient,
  }) {
    final String patientId = membership.patientId.trim();

    return SalesDocumentPatientSnapshot(
      patientId: patientId,
      patientNo: _clean(membership.patientNo) ?? patientId,
      fullName:
          _clean(patient.fullName) ??
          _clean(membership.patientDisplayName) ??
          patientId,
      dob: patient.dob,
      gender: patient.gender?.name,
      relationship: patient.relationship?.name,
      membershipId: membership.membershipId,
      memberNo: membership.memberNo,
      scheme: membership.scheme,
      payerName:
          _clean(membership.payerDisplayName) ?? membership.payerContactId,
    );
  }

  ZohoContact _payerContactFromMembership(InsuranceMembership membership) {
    final String payerName =
        _clean(membership.payerDisplayName) ?? membership.payerContactId;

    return ZohoContact(
      contactId: membership.payerContactId.trim(),
      displayName: payerName,
      accountNumber: _clean(membership.payerAccountNumber),
      contactType: 'customer',
      isInsurancePayer: true,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String? patientId = _patientId;

    final PrescriptionsState prescriptionState = patientId == null
        ? const PrescriptionsState()
        : ref.watch(prescriptionsControllerProvider(patientId));

    final InsuranceMembershipsState membershipsState = ref.watch(
      insuranceMembershipsControllerProvider,
    );

    final Set<String>? allowedPatientIds = _allowedPatientIdsForMemberships();

    _hydrateInitialSelections(
      memberships: membershipsState.items,
      prescriptions: prescriptionState.items,
    );

    final int membershipCount = membershipsState.visibleActiveCount(
      patientId: patientId,
      allowedPatientIds: allowedPatientIds,
    );

    final double membershipPickerHeight = _membershipPickerHeight(
      membershipCount,
    );

    int question = 0;

    final List<Widget> children = <Widget>[
      QuoteDetailsQuestionSection(
        number: ++question,
        complete: true,
        title: 'What is this purchase for?',
        child: SegmentedButton<QuotePurchaseContext>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<QuotePurchaseContext>>[
            ButtonSegment<QuotePurchaseContext>(
              value: QuotePurchaseContext.privateUse,
              icon: Icon(Icons.person_outline),
              label: Text('Private use'),
            ),
            ButtonSegment<QuotePurchaseContext>(
              value: QuotePurchaseContext.company,
              icon: Icon(Icons.business_outlined),
              label: Text('Company'),
            ),
          ],
          selected: <QuotePurchaseContext>{_draft.purchaseContext},
          onSelectionChanged: (Set<QuotePurchaseContext> selected) {
            if (selected.isEmpty) return;
            _setPurchaseContext(selected.first);
          },
        ),
      ),
    ];

    if (_draft.isPrivateUse) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        QuoteDetailsQuestionSection(
          number: ++question,
          complete: _profileComplete,
          title: 'Who is the quote for?',
          subtitle: _isMemberScoped
              ? 'Choose from your linked profiles.'
              : 'Choose the patient receiving the medicine.',
          child: ProfilePickerCard(
            selectedProfile: _profile,
            busy: false,
            contactId: _isMemberScoped ? _memberContactId : null,
            forcePickerMode: widget.isStaffMode,
            onChanged: (Profile profile) {
              _profile = profile;
              _pickProfileResult(profile);
            },
          ),
        ),
        const SizedBox(height: 18),
        QuoteDetailsQuestionSection(
          number: ++question,
          complete: !_requiresInsurance || _paymentComplete,
          title: 'How will this quote be paid?',
          child: SegmentedButton<QuotePaymentContext>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<QuotePaymentContext>>[
              ButtonSegment<QuotePaymentContext>(
                value: QuotePaymentContext.directPay,
                icon: Icon(Icons.payments_outlined),
                label: Text('Direct pay'),
              ),
              ButtonSegment<QuotePaymentContext>(
                value: QuotePaymentContext.insurance,
                icon: Icon(Icons.health_and_safety_outlined),
                label: Text('Insurance'),
              ),
            ],
            selected: <QuotePaymentContext>{_paymentContext},
            onSelectionChanged: (Set<QuotePaymentContext> selected) {
              if (selected.isEmpty) return;
              _setPaymentContext(selected.first);
            },
          ),
        ),
      ]);

      if (_requiresInsurance) {
        children.addAll(<Widget>[
          const SizedBox(height: 18),
          QuoteDetailsQuestionSection(
            number: ++question,
            complete: _paymentComplete,
            title: 'Which insurance membership applies?',
            child: SizedBox(
              height: membershipPickerHeight,
              child: InsuranceMembershipPickerCard(
                initialMembershipId:
                    _membership?.membershipId ?? _draft.resolvedMembershipId,
                patientId: patientId,
                allowedPatientIds: allowedPatientIds,
                title: _isMemberScoped
                    ? 'Your insurance memberships'
                    : 'Insurance memberships',
                emptyText: _isMemberScoped
                    ? 'No insurance memberships found for your linked profiles.'
                    : 'No active insurance memberships found.',
                onSelected: _setMembership,
              ),
            ),
          ),
        ]);
      }

      children.addAll(<Widget>[
        const SizedBox(height: 18),
        QuoteDetailsQuestionSection(
          number: ++question,
          complete: _requiresInsurance
              ? _prescriptionComplete
              : _hasPrescription,
          requiredQuestion: _requiresInsurance,
          title: 'Is there a prescription?',
          subtitle: _requiresInsurance
              ? 'Required for an insurance quote.'
              : 'Optional for a direct-pay quote.',
          child: PrescriptionPickerCard(
            patientId: patientId,
            prescriptions: prescriptionState.items,
            selectedPrescriptionId:
                _prescription?.prescriptionId ?? _draft.resolvedPrescriptionId,
            busy: prescriptionState.busy || _uploadingPrescription,
            error: prescriptionState.error,
            requiredForClaim: _requiresInsurance,
            onRefresh: patientId == null
                ? null
                : () => _loadPrescriptions(patientId),
            onUpload: patientId == null ? null : _uploadPrescription,
            onChanged: _setPrescription,
          ),
        ),
      ]);
    } else {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        QuoteDetailsQuestionSection(
          number: ++question,
          complete: true,
          title: 'Who will be billed?',
          child: const QuoteDetailsCompanyTile(),
        ),
      ]);
    }

    children.addAll(<Widget>[
      const SizedBox(height: 18),
      QuoteDetailsQuestionSection(
        number: ++question,
        complete: _fulfilmentComplete,
        title: 'How will the order be received?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SegmentedButton<QuoteFulfilmentMethod>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<QuoteFulfilmentMethod>>[
                ButtonSegment<QuoteFulfilmentMethod>(
                  value: QuoteFulfilmentMethod.delivery,
                  icon: Icon(Icons.local_shipping_outlined),
                  label: Text('Delivery'),
                ),
                ButtonSegment<QuoteFulfilmentMethod>(
                  value: QuoteFulfilmentMethod.pickup,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Pickup'),
                ),
              ],
              selected: <QuoteFulfilmentMethod>{_draft.fulfilmentMethod},
              onSelectionChanged: (Set<QuoteFulfilmentMethod> selected) {
                if (selected.isEmpty) return;
                _setFulfilmentMethod(selected.first);
              },
            ),
            const SizedBox(height: 10),
            if (_draft.fulfilmentMethod.isDelivery)
              QuoteDetailsDeliveryLocationTile(
                address: _draft.deliveryAddress,
                onTap: _pickDeliveryLocation,
                onClear: _draft.deliveryAddress == null
                    ? null
                    : () {
                        _patch(_draft.copyWith(clearDeliveryAddress: true));
                      },
              )
            else
              const QuoteDetailsPickupTile(),
          ],
        ),
      ),
    ]);

    if (widget.isStaffMode) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        QuoteDetailsQuestionSection(
          number: ++question,
          complete: _staffDetailsComplete,
          title: 'Quote information',
          subtitle: 'Staff-only dates, reference and customer notes.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              QuoteDetailsDateFields(
                quoteDate: _draft.quoteDate,
                expiryDate: _draft.expiryDate,
                onPickQuoteDate: _pickQuoteDate,
                onClearQuoteDate: () {
                  _patch(_draft.copyWith(clearQuoteDate: true));
                },
                onPickExpiryDate: _pickExpiryDate,
                onClearExpiryDate: () {
                  _patch(_draft.copyWith(clearExpiryDate: true));
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Reference',
                  hintText: _draft.isCompany
                      ? 'e.g. LPO / PO number'
                      : 'e.g. reference number',
                  border: const OutlineInputBorder(),
                ),
                onChanged: _setReference,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Customer notes',
                  hintText: 'Notes on the quote…',
                  border: OutlineInputBorder(),
                ),
                onChanged: _setCustomerNotes,
              ),
            ],
          ),
        ),
      ]);
    }

    return AppBottomSheetScaffold(
      title: 'Quote details',
      subtitle: 'Complete each numbered question.',
      leading: const Icon(Icons.tune_outlined),
      bodyPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      footer: QuoteDetailsSheetFooter(
        canSubmit: _canSubmit,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  void _pickProfileResult(Profile profile) {
    final String? previousPatientId = _clean(_draft.resolvedPatientId);
    final String nextPatientId = profile.profileId.trim();

    setState(() {
      _profile = profile;

      if (previousPatientId != null && previousPatientId != nextPatientId) {
        _membership = null;
        _prescription = null;
      }

      _draft = _draft.copyWith(
        purchaseContext: QuotePurchaseContext.privateUse,
        paymentContext: _paymentContext,
        patientSnapshot: _snapshotFromProfile(profile),
        clearMembershipId:
            previousPatientId != null && previousPatientId != nextPatientId,
        clearPrescriptionId:
            previousPatientId != null && previousPatientId != nextPatientId,
        clearPrescriptionLabel:
            previousPatientId != null && previousPatientId != nextPatientId,
      );
    });

    _loadPrescriptions(nextPatientId);
  }
}

String _prescriptionLabel(Prescription prescription) {
  final List<String> parts = <String>[
    if (_clean(prescription.fileName) != null) prescription.fileName.trim(),
    if (_clean(prescription.prescribedOn) != null)
      prescription.prescribedOn!.trim(),
    prescription.status.label,
  ];

  final String result = parts
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' · ')
      .trim();

  return result.isEmpty ? prescription.prescriptionId : result;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _defaultExpiry(DateTime quoteDate) {
  return _dateOnly(quoteDate.add(const Duration(days: 30)));
}

String? _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

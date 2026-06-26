// lib/core/home/activities/shared/member_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/activities/contacts/contact_activity_adapter.dart';
import 'package:afyakit/core/home/activities/contacts/contact_activity_providers.dart';
import 'package:afyakit/core/home/activities/patients/patient_activity_adapter.dart';
import 'package:afyakit/core/home/activities/patients/patient_activity_providers.dart';
import 'package:afyakit/core/home/activities/quotes/quote_activity_adapter.dart';
import 'package:afyakit/core/home/activities/quotes/quote_activity_providers.dart';
import 'package:afyakit/core/home/activities/shared/latest_activity_panel.dart';

import 'package:afyakit/features/clinical/patients/widgets/patient_details_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';

class MemberLatestActivityPanel extends ConsumerWidget {
  const MemberLatestActivityPanel({
    super.key,
    required this.contactId,
    this.accountNumber,
    this.maxItems = 5,
    this.onTitleTap,
    this.title = 'Latest Activity',
    this.emptyText = 'No recent member activity yet.',
  });

  /// Real Zoho/contact ID used by clinical patient-contact links.
  final String? contactId;

  /// Member/account number used by some retail documents.
  final String? accountNumber;

  final int? maxItems;
  final VoidCallback? onTitleTap;
  final String title;
  final String emptyText;

  static const int _fallbackMaxItems = 5;

  String? get _cleanContactId {
    final id = contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? get _cleanAccountNumber {
    final id = accountNumber?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopedContactId = _cleanContactId;
    final scopedAccountNumber = _cleanAccountNumber;

    if (scopedContactId == null && scopedAccountNumber == null) {
      return const LatestActivityPanel(
        title: 'Latest Activity',
        icon: Icons.notifications_none,
        loading: false,
        hasError: false,
        entries: <ActivityEntry>[],
        emptyText: 'No patient profiles linked to your account yet.',
        maxItems: _fallbackMaxItems,
      );
    }

    final patientsAsync = scopedContactId == null
        ? null
        : ref.watch(memberPatientActivityProvider(scopedContactId));

    final quotesAsync = ref.watch(
      memberSubmittedQuoteActivityProvider(
        MemberQuoteActivityScope(
          contactId: scopedContactId,
          accountNumber: scopedAccountNumber,
        ),
      ),
    );

    final customersAsync = ref.watch(
      memberCustomerActivityProvider(
        MemberCustomerActivityScope(
          contactId: scopedContactId,
          accountNumber: scopedAccountNumber,
        ),
      ),
    );

    final patientEntries = PatientActivityAdapter.fromPatients(
      patientsAsync?.valueOrNull ?? const [],
      onTapForPatient: (patient) {
        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailsScreen(
              patient: patient,
              contactId: scopedContactId,
              allowExplicitContactLink: false,
            ),
          ),
        );
      },
    );

    final quoteEntries = QuoteActivityAdapter.fromSubmittedQuotes(
      quotesAsync.valueOrNull ?? const [],
      onTapForQuote: (quote) {
        final quoteId = quote.quoteId.trim();
        if (quoteId.isEmpty) return null;

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                QuoteDetailScreen(quoteId: quoteId, forceStaffWorkspace: false),
          ),
        );
      },
    );

    final customerEntries = ContactActivityAdapter.fromCustomers(
      customersAsync.valueOrNull ?? const [],
      onTapForContact: (contact) {
        final contactId = contact.contactId.trim();
        if (contactId.isEmpty) return null;

        return () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ContactsScreen()));
      },
    );

    final entries = <ActivityEntry>[
      ...patientEntries,
      ...quoteEntries,
      ...customerEntries,
    ];

    return LatestActivityPanel(
      title: title,
      icon: Icons.notifications_none,
      loading:
          (patientsAsync?.isLoading ?? false) ||
          quotesAsync.isLoading ||
          customersAsync.isLoading,
      hasError:
          (patientsAsync?.hasError ?? false) ||
          quotesAsync.hasError ||
          customersAsync.hasError,
      errorText: 'Could not load activity.',
      entries: entries,
      emptyText: emptyText,
      maxItems: maxItems,
      onTitleTap: onTitleTap,
    );
  }
}

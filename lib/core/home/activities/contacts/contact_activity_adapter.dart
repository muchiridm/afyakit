// lib/core/home/activities/patients/patient_activity_adapter.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/core/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

typedef ContactActivityTapBuilder = VoidCallback? Function(ZohoContact contact);

class ContactActivityAdapter {
  const ContactActivityAdapter._();

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static List<ActivityEntry> fromCustomers(
    List<ZohoContact> contacts, {
    ContactActivityTapBuilder? onTapForContact,
  }) {
    return [
      for (final contact in contacts.where(_isActivityCustomer))
        ActivityEntry(
          date: _contactActivityDate(contact),
          widget: ActivityEventTile(
            icon: _contactIcon(contact),
            title:
                '${_activityTitlePrefix(contact)} • ${_contactLabel(contact)}',
            subtitle: _contactSubtitle(contact),
            timestamp: _timestampLabel(contact),
            onTap: onTapForContact?.call(contact),
          ),
        ),
    ];
  }

  static bool _isActivityCustomer(ZohoContact contact) {
    if (!contact.isActive) return false;

    // This activity adapter is for sales/customer activity only.
    // Keep customer_vendor because Zoho supports dual-role contacts.
    return contact.isCustomer;
  }

  static DateTime _contactActivityDate(ZohoContact contact) {
    return contact.activityDate;
  }

  static String _timestampLabel(ZohoContact contact) {
    final date = _contactActivityDate(contact);

    // Avoid showing meaningless "Created • Jan 1970" labels when Zoho/backend
    // has not supplied created_time or last_modified_time.
    if (date.isAtSameMomentAs(_epoch)) {
      return '';
    }

    return activityDateLabel(
      label: contact.lastModifiedTime != null ? 'Updated' : 'Created',
      date: date,
    );
  }

  static IconData _contactIcon(ZohoContact contact) {
    if (contact.isInsurancePayer) {
      return Icons.verified_user_outlined;
    }

    if (contact.isCompanyOnly) {
      return Icons.apartment_outlined;
    }

    return Icons.person_outline;
  }

  static String _activityTitlePrefix(ZohoContact contact) {
    if (contact.isInsurancePayer) return 'Insurance payer';
    if (contact.isCompanyOnly) return 'Customer company';
    return 'Customer';
  }

  static String _contactLabel(ZohoContact contact) {
    final accountNumber = (contact.accountNumber ?? '').trim();
    if (accountNumber.isNotEmpty) return accountNumber;

    final title = contact.title.trim();
    if (title.isNotEmpty) return title;

    final id = contact.contactId.trim();
    if (id.isNotEmpty) return id;

    return 'Customer';
  }

  static String _contactSubtitle(ZohoContact contact) {
    final parts = <String>[];

    final title = contact.title.trim();
    if (title.isNotEmpty) {
      parts.add(title);
    }

    final company = (contact.companyName ?? '').trim();
    if (company.isNotEmpty && company.toLowerCase() != title.toLowerCase()) {
      parts.add(company);
    }

    final phone = contact.bestPhone.trim();
    if (phone.isNotEmpty) {
      parts.add(phone);
    }

    final email = contact.bestEmail.trim();
    if (email.isNotEmpty) {
      parts.add(email);
    }

    final linked = contact.linkedPatientsSummary.trim();
    if (linked.isNotEmpty) {
      parts.add(linked);
    }

    if (contact.isInsurancePayer) {
      parts.add('Insurance payer');
    }

    return parts.take(4).join(' • ');
  }
}

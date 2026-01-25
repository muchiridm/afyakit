import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';

/// Cached per contactId by Riverpod.
/// Used by payments UI to show customer info without bloating DTOs.
final paymentContactSummaryProvider =
    FutureProvider.family<ZohoContact, String>((ref, contactId) async {
      final id = contactId.trim();
      if (id.isEmpty) {
        throw StateError('contactId is empty');
      }
      final svc = await ref.read(zohoContactsServiceProvider.future);
      return svc.get(id);
    });

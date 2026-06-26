// lib/core/home/activities/contacts/contact_activity_adapter.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';

const Duration contactActivityRefreshInterval = Duration(seconds: 15);

final staffCustomerActivityProvider =
    StreamProvider.autoDispose<List<ZohoContact>>((ref) {
      return _pollContacts(
        ref,
        fetch: (service) {
          return service.list(
            perPage: 100,
            page: 1,
            type: ZohoContactTypeFilter.customerOnly,
          );
        },
      );
    });

class MemberCustomerActivityScope {
  const MemberCustomerActivityScope({
    required this.contactId,
    required this.accountNumber,
  });

  final String? contactId;
  final String? accountNumber;

  String? get cleanContactId {
    final id = contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? get cleanAccountNumber {
    final id = accountNumber?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool get isEmpty => cleanContactId == null && cleanAccountNumber == null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemberCustomerActivityScope &&
            other.cleanContactId == cleanContactId &&
            other.cleanAccountNumber == cleanAccountNumber;
  }

  @override
  int get hashCode => Object.hash(cleanContactId, cleanAccountNumber);
}

final memberCustomerActivityProvider = StreamProvider.autoDispose
    .family<List<ZohoContact>, MemberCustomerActivityScope>((ref, scope) {
      if (scope.isEmpty) {
        return Stream.value(const <ZohoContact>[]);
      }

      return _pollContacts(
        ref,
        fetch: (service) async {
          final contactId = scope.cleanContactId;
          final accountNumber = scope.cleanAccountNumber;

          if (contactId != null) {
            final contact = await service.getLightOrNull(contactId);
            if (contact != null) return <ZohoContact>[contact];
          }

          if (accountNumber != null) {
            final contact = await service.getByAccountNumber(
              accountNumber,
              type: ZohoContactTypeFilter.customerOnly,
              forceRefresh: true,
            );

            if (contact != null) return <ZohoContact>[contact];
          }

          return const <ZohoContact>[];
        },
      );
    });

Stream<List<ZohoContact>> _pollContacts(
  Ref ref, {
  required Future<List<ZohoContact>> Function(ZohoContactsService service)
  fetch,
}) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(zohoContactsServiceProvider.future);
    final contacts = await fetch(service);

    if (cancelled) return;

    yield contacts;

    await Future<void>.delayed(contactActivityRefreshInterval);
  }
}

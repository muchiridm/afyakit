// lib/core/home/widgets/shared/activities/quote_activity_providers.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';

const Duration quoteActivityRefreshInterval = Duration(seconds: 15);

final staffSubmittedQuoteActivityProvider =
    StreamProvider.autoDispose<List<ZohoQuote>>((ref) {
      return _pollQuotes(
        ref,
        fetch: (service) {
          return service.list(limit: 50, page: 1);
        },
      );
    });

class MemberQuoteActivityScope {
  const MemberQuoteActivityScope({
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
        other is MemberQuoteActivityScope &&
            other.cleanContactId == cleanContactId &&
            other.cleanAccountNumber == cleanAccountNumber;
  }

  @override
  int get hashCode => Object.hash(cleanContactId, cleanAccountNumber);
}

final memberSubmittedQuoteActivityProvider = StreamProvider.autoDispose
    .family<List<ZohoQuote>, MemberQuoteActivityScope>((ref, scope) {
      if (scope.isEmpty) {
        return Stream.value(const <ZohoQuote>[]);
      }

      return _pollQuotes(
        ref,
        fetch: (service) async {
          final contactId = scope.cleanContactId;
          final accountNumber = scope.cleanAccountNumber;

          // First try Zoho customer/contact id.
          if (contactId != null) {
            final byContact = await service.list(
              limit: 50,
              page: 1,
              customerId: contactId,
            );

            if (byContact.isNotEmpty) return byContact;
          }

          // Fallback to member/account number if the quote was tagged that way.
          if (accountNumber != null) {
            return service.list(
              limit: 50,
              page: 1,
              accountNumber: accountNumber,
            );
          }

          return const <ZohoQuote>[];
        },
      );
    });

Stream<List<ZohoQuote>> _pollQuotes(
  Ref ref, {
  required Future<List<ZohoQuote>> Function(dynamic service) fetch,
}) async* {
  var cancelled = false;

  ref.onDispose(() {
    cancelled = true;
  });

  while (!cancelled) {
    final service = await ref.read(zohoQuotesServiceProvider.future);
    final quotes = await fetch(service);

    if (cancelled) return;

    yield quotes;

    await Future<void>.delayed(quoteActivityRefreshInterval);
  }
}

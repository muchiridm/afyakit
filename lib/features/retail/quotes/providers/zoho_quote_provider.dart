import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final zohoQuoteProvider = FutureProvider.autoDispose.family<ZohoQuote, String>((
  ref,
  quoteId,
) async {
  final svc = await ref.watch(zohoQuotesServiceProvider.future);
  return svc.get(quoteId);
});

// lib/features/retail/quotes/services/zoho_quotes_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/quotes/models/quote_line_draft.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final zohoQuotesServiceProvider = FutureProvider<ZohoQuotesService>((
  Ref ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider);
  final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
  final AfyaKitClient api = await ref.watch(afyakitClientFutureProvider.future);

  return ZohoQuotesService(api: api, routes: routes);
});

class QuoteConversionResult {
  const QuoteConversionResult({required this.invoice, this.claimPackId});

  final JsonMap invoice;
  final String? claimPackId;

  factory QuoteConversionResult.fromJson(JsonMap json) {
    final Object? rawInvoice = json['invoice'];

    if (rawInvoice is! Map) {
      throw StateError('Unexpected response: missing "invoice"');
    }

    return QuoteConversionResult(
      invoice: rawInvoice.cast<String, dynamic>(),
      claimPackId: ZohoQuotesService.asCleanStringOrNull(
        json['claim_pack_id']?.toString(),
      ),
    );
  }
}

class ZohoQuotesService {
  ZohoQuotesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static final DateFormat _zohoDateFmt = DateFormat('yyyy-MM-dd');

  Future<List<ZohoQuote>> list({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
    String? customerId,
  }) async {
    final String query = (q ?? '').trim();
    final String account = (accountNumber ?? '').trim();
    final String customer = (customerId ?? '').trim();

    final Uri uri = routes.retailListQuotes(
      limit: limit,
      page: page,
      q: query.isEmpty ? null : query,
      accountNumber: account.isEmpty ? null : account,
      customerId: customer.isEmpty ? null : customer,
    );

    final Response<dynamic> response = await api.getUri(uri);

    final JsonMap data = _asJsonMap(response.data);
    final Object? rawQuotes = data['quotes'];

    if (rawQuotes is! List) {
      return const <ZohoQuote>[];
    }

    return rawQuotes
        .whereType<Map>()
        .map((Map<dynamic, dynamic> map) {
          return ZohoQuote.fromJson(map.cast<String, dynamic>());
        })
        .toList(growable: false);
  }

  Future<ZohoQuote> get(String quoteId) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    final Uri uri = routes.retailGetQuote(id);
    final Response<dynamic> response = await api.getUri(uri);

    final JsonMap data = _asJsonMap(response.data);
    final Object? rawQuote = data['quote'];

    if (rawQuote is Map) {
      return ZohoQuote.fromJson(rawQuote.cast<String, dynamic>());
    }

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<ZohoQuote?> getOrNull(String quoteId) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      return null;
    }

    final Uri uri = routes.retailGetQuote(id);

    try {
      final Response<dynamic> response = await api.getUri(uri);

      final JsonMap data = _asJsonMap(response.data);
      final Object? rawQuote = data['quote'];

      if (rawQuote is Map) {
        return ZohoQuote.fromJson(rawQuote.cast<String, dynamic>());
      }

      throw StateError('Unexpected response: missing "quote"');
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<ZohoQuote> createFromDraft(
    QuoteDraft draft, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    final JsonMap body = _buildDraftPayload(
      draft,
      requireCustomer: true,
      requireQuoteDate: true,
      requirePatient: draft.requiresPatient,
      requireFulfilment: true,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final Uri uri = routes.retailCreateQuote();

    final Response<dynamic> response = await api.postUri(uri, data: body);

    final JsonMap data = _asJsonMap(response.data);
    final Object? rawQuote = data['quote'];

    if (rawQuote is Map) {
      return ZohoQuote.fromJson(rawQuote.cast<String, dynamic>());
    }

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<ZohoQuote> updateFromDraft(
    String quoteId,
    QuoteDraft draft, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    final JsonMap body = _buildDraftPayload(
      draft,
      requireCustomer: false,
      requireQuoteDate: false,
      requirePatient: false,
      requireFulfilment: false,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final Uri uri = routes.retailUpdateQuote(id);

    final Response<dynamic> response = await api.putUri(uri, data: body);

    final JsonMap data = _asJsonMap(response.data);
    final Object? rawQuote = data['quote'];

    if (rawQuote is Map) {
      return ZohoQuote.fromJson(rawQuote.cast<String, dynamic>());
    }

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<void> delete(String quoteId) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    await api.deleteUri(routes.retailDeleteQuote(id));
  }

  Future<Uint8List> getPdf(String quoteId) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    final Response<dynamic> response = await api.getUri(
      routes.retailQuotePdf(id),
      options: Options(
        responseType: ResponseType.bytes,
        headers: const <String, String>{'Accept': 'application/pdf'},
      ),
    );

    final Object? data = response.data;

    if (data is Uint8List) {
      return data;
    }

    if (data is List<int>) {
      return Uint8List.fromList(data);
    }

    throw StateError('Expected PDF bytes but got ${data.runtimeType}');
  }

  Future<void> email(String quoteId, {ZohoEmailDraft? draft}) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    final Map<String, Object?> payload = _pruneEmailJson(
      draft?.toJson() ?? const <String, Object?>{},
    );

    await api.postUri(
      routes.retailSendQuote(id),
      data: payload.isEmpty ? null : payload,
    );
  }

  Future<void> markSent(String quoteId) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    await api.postUri(routes.retailMarkQuoteSent(id));
  }

  Future<void> emailAndMarkSent(String quoteId, {ZohoEmailDraft? draft}) async {
    if (draft != null) {
      await email(quoteId, draft: draft);
    }

    await markSent(quoteId);
  }

  Future<void> emailQuote(String quoteId, {ZohoEmailDraft? draft}) {
    return email(quoteId, draft: draft);
  }

  Future<QuoteConversionResult> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? membershipId,
    String? prescriptionId,
    SalesDocumentPatientSnapshot? patientSnapshot,
    SalesDocumentAddress? deliveryAddress,
  }) async {
    final String id = quoteId.trim();

    if (id.isEmpty) {
      throw StateError('quoteId is empty');
    }

    final String? cleanMembershipId = asCleanStringOrNull(membershipId);

    final String? cleanPrescriptionId = asCleanStringOrNull(prescriptionId);

    final Map<String, Object?> body = <String, Object?>{
      if (invoiceDate != null)
        'invoice_date': _zohoDateFmt.format(_dateOnly(invoiceDate)),
      if (dueDate != null) 'due_date': _zohoDateFmt.format(_dateOnly(dueDate)),
      if (deliveryAddress != null) 'delivery_address': deliveryAddress.toJson(),
      if (patientSnapshot != null) ...<String, Object?>{
        'patient_id': patientSnapshot.patientId,
        'patient_snapshot': patientSnapshot.toJson(),
      },
      if (cleanMembershipId != null) 'membership_id': cleanMembershipId,
      if (cleanPrescriptionId != null) 'prescription_id': cleanPrescriptionId,
    };

    final Response<dynamic> response = await api.postUri(
      routes.retailConvertQuoteToInvoice(id),
      data: body.isEmpty ? null : body,
    );

    return QuoteConversionResult.fromJson(_asJsonMap(response.data));
  }

  Future<QuoteConversionResult> convertDraftToInvoice(
    String quoteId,
    QuoteDraft draft, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) {
    return convertToInvoice(
      quoteId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      membershipId: draft.resolvedMembershipId,
      prescriptionId: draft.resolvedPrescriptionId,
      patientSnapshot: draft.patientSnapshot,
      deliveryAddress: draft.fulfilmentMethod.isDelivery
          ? draft.deliveryAddress
          : null,
    );
  }

  JsonMap _buildDraftPayload(
    QuoteDraft draft, {
    required bool requireCustomer,
    required bool requireQuoteDate,
    required bool requirePatient,
    required bool requireFulfilment,
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) {
    final String customerId = draft.customerIdResolved.trim();

    if (requireCustomer && customerId.isEmpty) {
      throw StateError('Please select a customer before requesting a quote.');
    }

    if (!draft.hasLines) {
      throw StateError(
        'Please add at least one item before requesting a quote.',
      );
    }

    final String? quoteDateValue = quoteDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(quoteDate));

    final String? expiryDateValue = expiryDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(expiryDate));

    if (requireQuoteDate && quoteDateValue == null) {
      throw StateError('Please select a quote date before requesting a quote.');
    }

    final String? patientId = asCleanStringOrNull(draft.resolvedPatientId);

    final String? membershipId = asCleanStringOrNull(
      draft.resolvedMembershipId,
    );

    final String? prescriptionId = asCleanStringOrNull(
      draft.resolvedPrescriptionId,
    );

    final QuotePaymentContext paymentContext = draft.effectivePaymentContext;

    if (draft.isCompany && paymentContext.isInsurance) {
      throw StateError('Insurance is only available for private-use quotes.');
    }

    if (requirePatient && patientId == null) {
      throw StateError('Please select who the quote is for.');
    }

    if (requirePatient && draft.patientSnapshot == null) {
      throw StateError('Please select who the quote is for.');
    }

    if (requireFulfilment && !draft.hasFulfilmentContext) {
      throw StateError(
        draft.fulfilmentMethod.isDelivery
            ? 'Please select a delivery location.'
            : 'Please select delivery or pickup.',
      );
    }

    if (draft.requiresDeliveryLocation &&
        draft.deliveryAddress?.isUsable != true) {
      throw StateError('Please select a delivery location.');
    }

    if (draft.requiresMembership && membershipId == null) {
      throw StateError('Please select an insurance membership.');
    }

    if (draft.requiresPrescription && prescriptionId == null) {
      throw StateError('Please select or upload a prescription.');
    }

    final String? reference = asCleanStringOrNull(draft.reference);

    final String? notes = asCleanStringOrNull(draft.customerNotes);

    final SalesDocumentAddress? deliveryAddress =
        draft.fulfilmentMethod.isDelivery ? draft.deliveryAddress : null;

    return <String, Object?>{
      // Keep existing backend field and values.
      'sale_context': draft.purchaseContext.apiValue,
      'payment_context': paymentContext.apiValue,

      'fulfilment_method': draft.fulfilmentMethod.apiValue,

      if (customerId.isNotEmpty) 'customer_id': customerId,
      if (quoteDateValue != null) 'date': quoteDateValue,
      if (expiryDateValue != null) 'expiry_date': expiryDateValue,
      if (reference != null) 'reference_number': reference,
      if (notes != null) 'notes': notes,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress.toJson(),
      if (patientId != null) 'patient_id': patientId,
      if (draft.patientSnapshot != null)
        'patient_snapshot': draft.patientSnapshot!.toJson(),
      if (draft.isInsurancePayment && membershipId != null)
        'membership_id': membershipId,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      'line_items': draft.lines
          .where((QuoteLineDraft line) {
            return line.safeQty > 0;
          })
          .map((QuoteLineDraft line) {
            final String? lineItemId = asCleanStringOrNull(line.lineItemId);

            final String? itemId = asCleanStringOrNull(line.zohoItemId);

            final String? unit = asCleanStringOrNull(line.unit);

            final String name = _safeLineName(line);
            final String? description = _safeLineDescription(line);

            return <String, Object?>{
              if (lineItemId != null) 'line_item_id': lineItemId,
              if (itemId != null) 'item_id': itemId,
              'name': name,
              if (description != null) 'description': description,
              'quantity': _safeQty(line.quantity),
              'rate': _safeRate(line.rate),
              if (unit != null) 'unit': unit,
            };
          })
          .toList(growable: false),
    };
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static Map<String, Object?> _pruneEmailJson(Map<String, Object?> input) {
    final Map<String, Object?> output = <String, Object?>{...input};

    void removeEmptyList(String key) {
      final Object? value = output[key];

      if (value is List && value.isEmpty) {
        output.remove(key);
      }
    }

    removeEmptyList('to_mail_ids');
    removeEmptyList('cc_mail_ids');
    removeEmptyList('bcc_mail_ids');
    removeEmptyList('contact_person_ids');

    output.removeWhere((String key, Object? value) {
      return value is String && value.trim().isEmpty;
    });

    return output;
  }

  static String? asCleanStringOrNull(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static int _safeQty(int quantity) {
    if (quantity < 1) return 1;
    if (quantity > 9999) return 9999;

    return quantity;
  }

  static num _safeRate(num rate) {
    if (rate.isNaN || rate.isInfinite || rate < 0) {
      return 0;
    }

    return rate;
  }

  static String _safeLineName(QuoteLineDraft line) {
    final String description = (line.description ?? '').trim();

    if (description.isNotEmpty) {
      return _truncate(description, 120);
    }

    final String title = line.tile.tileTitle.trim();

    if (title.isNotEmpty) {
      return _truncate(title, 120);
    }

    final String fallback = (line.tile.tileDesc ?? '').trim();

    return _truncate(fallback.isNotEmpty ? fallback : 'Item', 120);
  }

  static String? _safeLineDescription(QuoteLineDraft line) {
    final String description = (line.tile.tileDesc ?? '').trim();

    if (description.isEmpty) {
      return null;
    }

    return _truncate(description, 500);
  }

  static String _truncate(String value, int max) {
    final String text = value.trim();

    if (text.length <= max) {
      return text;
    }

    return text.substring(0, max - 1).trimRight();
  }

  static JsonMap _asJsonMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    throw StateError('Expected JSON object but got ${value.runtimeType}');
  }
}

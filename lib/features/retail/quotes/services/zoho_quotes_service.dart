// lib/features/retail/quotes/services/zoho_quotes_service.dart

import 'dart:typed_data';

import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import '../models/quote_draft.dart';
import '../models/zoho_quote.dart';

final zohoQuotesServiceProvider = FutureProvider<ZohoQuotesService>((
  Ref ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider);
  final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
  final AfyaKitClient api = await ref.watch(afyakitClientFutureProvider.future);

  return ZohoQuotesService(api: api, routes: routes);
});

class QuoteConversionResult {
  const QuoteConversionResult({required this.invoice, this.claim});

  final JsonMap invoice;
  final InsuranceClaim? claim;

  bool get hasClaim => claim != null;

  factory QuoteConversionResult.fromJson(JsonMap json) {
    final Object? rawInvoice = json['invoice'];
    if (rawInvoice is! Map) {
      throw StateError('Unexpected response: missing "invoice"');
    }

    final Object? rawClaim = json['claim'];
    final InsuranceClaim? claim = rawClaim is Map
        ? InsuranceClaim.fromJson(rawClaim.cast<String, Object?>())
        : null;

    return QuoteConversionResult(
      invoice: rawInvoice.cast<String, dynamic>(),
      claim: claim,
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
  }) async {
    final String qq = (q ?? '').trim();
    final String acct = (accountNumber ?? '').trim();

    final Uri uri = routes.retailListQuotes(
      limit: limit,
      page: page,
      q: qq.isEmpty ? null : qq,
      accountNumber: acct.isEmpty ? null : acct,
    );

    final Response<dynamic> res = await api.getUri(uri);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['quotes'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((Map<dynamic, dynamic> map) {
            return ZohoQuote.fromJson(map.cast<String, dynamic>());
          })
          .toList(growable: false);
    }

    return const <ZohoQuote>[];
  }

  Future<ZohoQuote> get(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailGetQuote(id);
    final Response<dynamic> res = await api.getUri(uri);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['quote'];

    if (raw is Map) {
      return ZohoQuote.fromJson(raw.cast<String, dynamic>());
    }

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<ZohoQuote?> getOrNull(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return null;

    final Uri uri = routes.retailGetQuote(id);

    try {
      final Response<dynamic> res = await api.getUri(uri);

      final JsonMap data = _asJsonMap(res.data);
      final Object? raw = data['quote'];

      if (raw is Map) {
        return ZohoQuote.fromJson(raw.cast<String, dynamic>());
      }

      throw StateError('Unexpected response: missing "quote"');
    } on DioException catch (e) {
      final int? code = e.response?.statusCode;
      if (code == 404) return null;
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
      requireDeliveryAddress: draft.requiresDeliveryAddress,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final Uri uri = routes.retailCreateQuote();
    final Response<dynamic> res = await api.postUri(uri, data: body);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['quote'];

    if (raw is Map) {
      return ZohoQuote.fromJson(raw.cast<String, dynamic>());
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
    if (id.isEmpty) throw StateError('quoteId is empty');

    final JsonMap body = _buildDraftPayload(
      draft,
      requireCustomer: false,
      requireQuoteDate: false,
      requirePatient: false,
      requireDeliveryAddress: false,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final Uri uri = routes.retailUpdateQuote(id);
    final Response<dynamic> res = await api.putUri(uri, data: body);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['quote'];

    if (raw is Map) {
      return ZohoQuote.fromJson(raw.cast<String, dynamic>());
    }

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<void> delete(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailDeleteQuote(id);
    await api.deleteUri(uri);
  }

  Future<Uint8List> getPdf(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailQuotePdf(id);

    final Response<dynamic> res = await api.getUri(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const <String, String>{'Accept': 'application/pdf'},
      ),
    );

    final Object? data = res.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);

    throw StateError('Expected PDF bytes but got ${data.runtimeType}');
  }

  Future<void> email(String quoteId, {ZohoEmailDraft? draft}) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailSendQuote(id);

    final Map<String, Object?> payload = _pruneEmailJson(
      draft?.toJson() ?? const <String, Object?>{},
    );

    await api.postUri(uri, data: payload.isEmpty ? null : payload);
  }

  Future<void> markSent(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailMarkQuoteSent(id);
    await api.postUri(uri);
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
    bool createInsuranceClaim = false,
    SalesDocumentPatientSnapshot? patientSnapshot,
    SalesDocumentAddress? deliveryAddress,
  }) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final Uri uri = routes.retailConvertQuoteToInvoice(id);

    final String? cleanMembershipId = asCleanStringOrNull(membershipId);
    final String? cleanPrescriptionId = asCleanStringOrNull(prescriptionId);

    if (createInsuranceClaim && cleanMembershipId == null) {
      throw StateError('Please select an insurance membership.');
    }

    if (createInsuranceClaim && cleanPrescriptionId == null) {
      throw StateError('Please select a verified prescription.');
    }

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
      if (createInsuranceClaim) 'create_insurance_claim': true,
    };

    final Response<dynamic> res = await api.postUri(
      uri,
      data: body.isEmpty ? null : body,
    );

    return QuoteConversionResult.fromJson(_asJsonMap(res.data));
  }

  Future<QuoteConversionResult> convertDraftToInvoice(
    String quoteId,
    QuoteDraft draft, {
    DateTime? invoiceDate,
    DateTime? dueDate,
    bool createInsuranceClaim = false,
  }) {
    return convertToInvoice(
      quoteId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,

      // Always carry clinical/insurance context forward to the invoice.
      // Claim creation is no longer done during quote → invoice conversion.
      membershipId: draft.resolvedMembershipId,
      prescriptionId: draft.resolvedPrescriptionId,

      // Deprecated behaviour. Claims are created separately after claim document upload.
      createInsuranceClaim: false,

      patientSnapshot: draft.patientSnapshot,
      deliveryAddress: draft.deliveryAddress,
    );
  }

  JsonMap _buildDraftPayload(
    QuoteDraft draft, {
    required bool requireCustomer,
    required bool requireQuoteDate,
    required bool requirePatient,
    required bool requireDeliveryAddress,
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

    final String? quoteDateStr = quoteDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(quoteDate));

    final String? expiryDateStr = expiryDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(expiryDate));

    if (requireQuoteDate && quoteDateStr == null) {
      throw StateError('Please select a quote date before requesting a quote.');
    }

    final String? cleanPatientId = asCleanStringOrNull(draft.resolvedPatientId);
    final String? cleanMembershipId = asCleanStringOrNull(
      draft.resolvedMembershipId,
    );
    final String? cleanPrescriptionId = asCleanStringOrNull(
      draft.resolvedPrescriptionId,
    );

    if (draft.saleContext == QuoteSaleContext.general &&
        draft.paymentContext == QuotePaymentContext.insurance) {
      throw StateError('Insurance payment requires a clinical quote.');
    }

    if (requirePatient && cleanPatientId == null) {
      throw StateError(
        'Please select a patient profile before requesting a quote.',
      );
    }

    if (requirePatient && draft.patientSnapshot == null) {
      throw StateError(
        'Please select a patient profile before requesting a quote.',
      );
    }

    if (requireDeliveryAddress && draft.deliveryAddress?.isUsable != true) {
      throw StateError(
        'Please select a delivery address before requesting a quote.',
      );
    }

    if (draft.requiresMembership && cleanMembershipId == null) {
      throw StateError('Please select an insurance membership.');
    }

    if (draft.requiresPrescription && cleanPrescriptionId == null) {
      throw StateError('Please select a verified prescription.');
    }

    final String? reference = asCleanStringOrNull(draft.reference);
    final String? notes = asCleanStringOrNull(draft.customerNotes);

    final QuotePaymentContext effectivePaymentContext =
        draft.saleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : draft.paymentContext;

    return <String, Object?>{
      'sale_context': draft.saleContext.apiValue,
      'payment_context': effectivePaymentContext.apiValue,
      if (customerId.isNotEmpty) 'customer_id': customerId,
      if (quoteDateStr != null) 'date': quoteDateStr,
      if (expiryDateStr != null) 'expiry_date': expiryDateStr,
      if (reference != null) 'reference_number': reference,
      if (notes != null) 'notes': notes,
      if (draft.deliveryAddress != null)
        'delivery_address': draft.deliveryAddress!.toJson(),
      if (cleanPatientId != null) 'patient_id': cleanPatientId,
      if (draft.patientSnapshot != null)
        'patient_snapshot': draft.patientSnapshot!.toJson(),
      if (cleanMembershipId != null) 'membership_id': cleanMembershipId,
      if (cleanPrescriptionId != null) 'prescription_id': cleanPrescriptionId,
      'line_items': draft.lines
          .where((QuoteLineDraft line) => line.safeQty > 0)
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
    final Map<String, Object?> out = <String, Object?>{...input};

    void dropEmptyList(String key) {
      final Object? value = out[key];
      if (value is List && value.isEmpty) out.remove(key);
    }

    dropEmptyList('to_mail_ids');
    dropEmptyList('cc_mail_ids');
    dropEmptyList('bcc_mail_ids');
    dropEmptyList('contact_person_ids');

    out.removeWhere((String key, Object? value) {
      return value is String && value.trim().isEmpty;
    });

    return out;
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
    if (rate.isNaN || rate.isInfinite) return 0;
    if (rate < 0) return 0;
    return rate;
  }

  static String _safeLineName(QuoteLineDraft line) {
    final String description = (line.description ?? '').trim();
    if (description.isNotEmpty) return _truncate(description, 120);

    final String title = line.tile.tileTitle.trim();
    if (title.isNotEmpty) return _truncate(title, 120);

    final String fallback = (line.tile.tileDesc ?? '').trim();
    return _truncate(fallback.isNotEmpty ? fallback : 'Item', 120);
  }

  static String? _safeLineDescription(QuoteLineDraft line) {
    final String description = (line.tile.tileDesc ?? '').trim();
    if (description.isEmpty) return null;

    return _truncate(description, 500);
  }

  static String _truncate(String value, int max) {
    final String text = value.trim();
    if (text.length <= max) return text;

    return text.substring(0, max - 1).trimRight();
  }

  static JsonMap _asJsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();

    throw StateError('Expected JSON object but got ${value.runtimeType}');
  }
}

// lib/features/retail/shared/models/zoho_invoice.dart

import 'package:afyakit/features/retail/invoices/models/zoho_invoice_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/shared/utils/utils.dart';

import '../../payments/models/zoho_invoice_payment.dart';

class ZohoInvoice {
  const ZohoInvoice({
    required this.invoiceId,
    required this.customerName,
    required this.status,
    required this.date,
    required this.total,
    this.invoiceNumber,
    this.accountNumber,
    this.currencyCode,
    this.customerId,
    this.customerEmail,
    this.contactPersonIds = const <String>[],
    this.notes,
    this.terms,
    this.dueDate,
    this.balance,
    this.deliveryAddress,
    this.patientId,
    this.patientNo,
    this.patientName,
    this.saleContext,
    this.paymentContext,
    this.membershipId,
    this.prescriptionId,
    this.claimPackId,
    this.lineItems = const <ZohoInvoiceLineItem>[],
    this.payments = const <ZohoInvoicePayment>[],
  });

  final String invoiceId;
  final String customerName;
  final String status;
  final DateTime? date;
  final num total;

  final String? invoiceNumber;

  /// Your app identity key.
  final String? accountNumber;

  final String? currencyCode;
  final String? customerId;

  /// Convenience only; Zoho email endpoint prefers contact_person_ids.
  final String? customerEmail;

  final List<String> contactPersonIds;

  final String? notes;
  final String? terms;

  final DateTime? dueDate;
  final num? balance;

  /// Snapshot of chosen delivery address at document time.
  final SalesDocumentAddress? deliveryAddress;

  /// Clinical / insurance context returned by AfyaKit backend.
  ///
  /// These are read from Zoho custom fields on the backend and normalised into
  /// snake_case JSON fields before reaching Flutter.
  final String? patientId;
  final String? patientNo;
  final String? patientName;

  /// Expected values:
  /// - clinical
  /// - general
  final String? saleContext;

  /// Expected values:
  /// - direct_pay
  /// - insurance
  final String? paymentContext;

  final String? membershipId;
  final String? prescriptionId;

  /// Internal AfyaKit claim-pack link.
  ///
  /// Backend maps this from Zoho invoice custom field: cf_claim_pack_id.
  final String? claimPackId;

  final List<ZohoInvoiceLineItem> lineItems;
  final List<ZohoInvoicePayment> payments;

  bool get hasRecipients {
    return contactPersonIds.isNotEmpty ||
        (customerEmail ?? '').trim().isNotEmpty;
  }

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get isClinical => resolvedSaleContext == 'clinical';

  bool get isGeneral => resolvedSaleContext == 'general';

  bool get isInsurancePayment => resolvedPaymentContext == 'insurance';

  bool get isDirectPay => resolvedPaymentContext == 'direct_pay';

  bool get hasClaimPack => resolvedClaimPackId != null;

  String? get resolvedPatientId {
    final String direct = (patientId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final String no = (patientNo ?? '').trim();
    return no.isEmpty ? null : no;
  }

  String? get resolvedPatientNo {
    final String no = (patientNo ?? '').trim();
    if (no.isNotEmpty) return no;

    final String id = (patientId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  String? get resolvedPatientName {
    final String value = (patientName ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get resolvedMembershipId {
    final String value = (membershipId ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get resolvedPrescriptionId {
    final String value = (prescriptionId ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get resolvedClaimPackId {
    final String value = (claimPackId ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String get resolvedSaleContext {
    final String value = (saleContext ?? '').trim();

    if (value == 'clinical' || value == 'general') {
      return value;
    }

    return resolvedPatientId == null ? 'general' : 'clinical';
  }

  String get resolvedPaymentContext {
    final String value = (paymentContext ?? '').trim();

    if (value == 'insurance' || value == 'direct_pay') {
      return value;
    }

    return 'direct_pay';
  }

  factory ZohoInvoice.fromJson(JsonMap json) {
    final JsonMap j = json.cast<String, Object?>();

    final String id = readString(j['invoice_id'] ?? j['id']).trim();
    final String? number = readStringOrNull(j['invoice_number'])?.trim();

    final String name = readString(
      j['customer_name'] ?? j['contact_name'],
    ).trim();
    final String status = readString(j['status']).trim();

    final DateTime? date = readDateTime(j['date']);
    final DateTime? dueDate = readDateTime(j['due_date']);

    final num total = readNum(j['total']);
    final num? balance = j.containsKey('balance')
        ? readNum(j['balance'])
        : null;

    final String? account = cleanStringOrNull(
      j['account_number'] ?? j['accountNumber'],
    );

    final String? currency = cleanStringOrNull(j['currency_code']);

    final String? customerId = cleanStringOrNull(j['customer_id']);
    final String? notes = cleanStringOrNull(j['notes']);
    final String? terms = cleanStringOrNull(j['terms']);

    final SalesDocumentAddress? deliveryAddress = _parseDeliveryAddress(
      j['delivery_address'] ?? j['deliveryAddress'] ?? j['shipping_address'],
    );

    final List<ZohoInvoiceLineItem> lines = _parseLineItems(j['line_items']);
    final List<ZohoInvoicePayment> pays = _parsePayments(
      j['payments'] ?? j['payment_details'],
    );

    final List<String> cpIds = <String>[
      ..._extractContactPersonIds(j['contact_persons']),
      ..._extractContactPersonIds(
        j['contact_person_details'] ?? j['contact_persons_details'],
      ),
    ];

    final List<String> dedupedCpIds = _dedupePreserveOrder(cpIds);

    final String? email = cleanStringOrNull(
      j['email'] ?? j['customer_email'] ?? j['contact_email'],
    );

    final String? patientNo = cleanStringOrNull(
      j['patient_no'] ?? j['patientNo'],
    );

    final String? patientId =
        cleanStringOrNull(j['patient_id'] ?? j['patientId']) ?? patientNo;

    final String? patientName = cleanStringOrNull(
      j['patient_name'] ?? j['patientName'],
    );

    final String? saleContext = cleanStringOrNull(
      j['sale_context'] ?? j['saleContext'],
    );

    final String? paymentContext = cleanStringOrNull(
      j['payment_context'] ?? j['paymentContext'],
    );

    final String? membershipId = cleanStringOrNull(
      j['membership_id'] ?? j['membershipId'],
    );

    final String? prescriptionId = cleanStringOrNull(
      j['prescription_id'] ?? j['prescriptionId'],
    );

    final String? claimPackId = cleanStringOrNull(
      j['claim_pack_id'] ?? j['claimPackId'],
    );

    return ZohoInvoice(
      invoiceId: id,
      invoiceNumber: number,
      customerName: name.isEmpty ? 'Customer' : name,
      status: status.isEmpty ? 'unknown' : status,
      date: date,
      dueDate: dueDate,
      total: total,
      balance: balance,
      accountNumber: account,
      currencyCode: currency,
      customerId: customerId,
      customerEmail: email,
      contactPersonIds: dedupedCpIds,
      notes: notes,
      terms: terms,
      deliveryAddress: deliveryAddress,
      patientId: patientId,
      patientNo: patientNo,
      patientName: patientName,
      saleContext: saleContext,
      paymentContext: paymentContext,
      membershipId: membershipId,
      prescriptionId: prescriptionId,
      claimPackId: claimPackId,
      lineItems: lines,
      payments: pays,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'status': status,
      'date': date?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'total': total,
      'balance': balance,
      'account_number': accountNumber,
      'currency_code': currencyCode,
      'customer_id': customerId,
      'customer_email': customerEmail,
      'contact_person_ids': contactPersonIds,
      'notes': notes,
      'terms': terms,
      'delivery_address': deliveryAddress?.toJson(),
      'patient_id': patientId,
      'patient_no': patientNo,
      'patient_name': patientName,
      'sale_context': saleContext,
      'payment_context': paymentContext,
      'membership_id': membershipId,
      'prescription_id': prescriptionId,
      'claim_pack_id': claimPackId,
      'line_items': lineItems
          .map((ZohoInvoiceLineItem item) => item.toJson())
          .toList(growable: false),
    }..removeWhere(removeEmpty);
  }

  ZohoInvoice copyWith({
    String? invoiceId,
    String? customerName,
    String? status,
    DateTime? date,
    num? total,
    String? invoiceNumber,
    bool clearInvoiceNumber = false,
    String? accountNumber,
    bool clearAccountNumber = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
    String? customerId,
    bool clearCustomerId = false,
    String? customerEmail,
    bool clearCustomerEmail = false,
    List<String>? contactPersonIds,
    String? notes,
    bool clearNotes = false,
    String? terms,
    bool clearTerms = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    num? balance,
    bool clearBalance = false,
    SalesDocumentAddress? deliveryAddress,
    bool clearDeliveryAddress = false,
    String? patientId,
    bool clearPatientId = false,
    String? patientNo,
    bool clearPatientNo = false,
    String? patientName,
    bool clearPatientName = false,
    String? saleContext,
    bool clearSaleContext = false,
    String? paymentContext,
    bool clearPaymentContext = false,
    String? membershipId,
    bool clearMembershipId = false,
    String? prescriptionId,
    bool clearPrescriptionId = false,
    String? claimPackId,
    bool clearClaimPackId = false,
    List<ZohoInvoiceLineItem>? lineItems,
    List<ZohoInvoicePayment>? payments,
  }) {
    return ZohoInvoice(
      invoiceId: invoiceId ?? this.invoiceId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: date ?? this.date,
      total: total ?? this.total,
      invoiceNumber: clearInvoiceNumber
          ? null
          : (invoiceNumber ?? this.invoiceNumber),
      accountNumber: clearAccountNumber
          ? null
          : (accountNumber ?? this.accountNumber),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      customerEmail: clearCustomerEmail
          ? null
          : (customerEmail ?? this.customerEmail),
      contactPersonIds: contactPersonIds ?? this.contactPersonIds,
      notes: clearNotes ? null : (notes ?? this.notes),
      terms: clearTerms ? null : (terms ?? this.terms),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      balance: clearBalance ? null : (balance ?? this.balance),
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      patientNo: clearPatientNo ? null : (patientNo ?? this.patientNo),
      patientName: clearPatientName ? null : (patientName ?? this.patientName),
      saleContext: clearSaleContext ? null : (saleContext ?? this.saleContext),
      paymentContext: clearPaymentContext
          ? null
          : (paymentContext ?? this.paymentContext),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      prescriptionId: clearPrescriptionId
          ? null
          : (prescriptionId ?? this.prescriptionId),
      claimPackId: clearClaimPackId ? null : (claimPackId ?? this.claimPackId),
      lineItems: lineItems ?? this.lineItems,
      payments: payments ?? this.payments,
    );
  }
}

SalesDocumentAddress? _parseDeliveryAddress(Object? raw) {
  if (raw is Map<String, dynamic>) {
    final SalesDocumentAddress parsed = SalesDocumentAddress.fromJson(raw);
    return parsed.isUsable ? parsed : null;
  }

  if (raw is Map) {
    final SalesDocumentAddress parsed = SalesDocumentAddress.fromJson(
      raw.cast<String, dynamic>(),
    );

    return parsed.isUsable ? parsed : null;
  }

  return null;
}

List<ZohoInvoiceLineItem> _parseLineItems(Object? raw) {
  final List<ZohoInvoiceLineItem> out = <ZohoInvoiceLineItem>[];

  if (raw is! List) return out;

  for (final Object? e in raw) {
    if (!isRecord(e)) continue;

    final JsonMap m = (e as Map).cast<String, dynamic>();
    out.add(ZohoInvoiceLineItem.fromJson(m));
  }

  return out;
}

List<ZohoInvoicePayment> _parsePayments(Object? raw) {
  final List<ZohoInvoicePayment> out = <ZohoInvoicePayment>[];

  if (raw is! List) return out;

  for (final Object? e in raw) {
    if (!isRecord(e)) continue;

    final JsonMap m = (e as Map).cast<String, dynamic>();
    out.add(ZohoInvoicePayment.fromJson(m));
  }

  return out;
}

List<String> _extractContactPersonIds(Object? cps) {
  final List<String> out = <String>[];

  if (cps is! List) return out;

  for (final Object? e in cps) {
    final String? id1 = readStringOrNull(e)?.trim();

    if (id1 != null && id1.isNotEmpty) {
      out.add(id1);
      continue;
    }

    if (!isRecord(e)) continue;

    final Map<String, Object?> m = (e as Map).cast<String, Object?>();
    final String? id2 = readStringOrNull(
      m['contact_person_id'] ?? m['id'],
    )?.trim();

    if (id2 != null && id2.isNotEmpty) out.add(id2);
  }

  return out;
}

List<String> _dedupePreserveOrder(List<String> xs) {
  final Set<String> seen = <String>{};
  final List<String> out = <String>[];

  for (final String x in xs) {
    final String t = x.trim();

    if (t.isEmpty) continue;
    if (seen.add(t)) out.add(t);
  }

  return out;
}

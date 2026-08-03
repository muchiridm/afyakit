// lib/features/retail/payments/mpesa/models/mpesa_stk_draft.dart

import '../../../../shared/utils/utils.dart';

class MpesaStkInitiateDraft {
  const MpesaStkInitiateDraft({
    required this.phone,
    required this.amount,
    required this.purpose,
    required this.purposeRef,
    required this.clientRequestId,
    this.accountReference,
    this.description,
  });

  final String phone;
  final num amount;

  /// e.g. "invoice"
  final String purpose;

  /// invoice_id
  final String purposeRef;

  /// ✅ unique per attempt (UUID or timestamp-based)
  final String clientRequestId;

  final String? accountReference;
  final String? description;

  JsonMap toJson() => <String, dynamic>{
    'phone': phone.trim(),
    'amount': amount,
    'purpose': purpose.trim(),
    'purposeRef': purposeRef.trim(),
    'clientRequestId': clientRequestId.trim(),
    if (accountReference != null && accountReference!.trim().isNotEmpty)
      'accountReference': accountReference!.trim(),
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
  };
}

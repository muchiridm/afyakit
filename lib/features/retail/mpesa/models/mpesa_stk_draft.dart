// lib/features/retail/payments/mpesa/models/mpesa_stk_draft.dart

import '../../../../shared/utils/utils.dart';

class MpesaStkInitiateDraft {
  const MpesaStkInitiateDraft({
    required this.phone,
    required this.amount,
    required this.purpose,
    required this.purposeRef,
    required this.clientRequestId,
  });

  final String phone;
  final num amount;

  /// e.g. "invoice"
  final String purpose;

  /// invoice_id
  final String purposeRef;

  /// ✅ unique per attempt (UUID or timestamp-based)
  final String clientRequestId;

  JsonMap toJson() => <String, dynamic>{
    'phone': phone.trim(),
    'amount': amount,
    'purpose': purpose.trim(),
    'purposeRef': purposeRef.trim(),
    'clientRequestId': clientRequestId.trim(),
  };
}

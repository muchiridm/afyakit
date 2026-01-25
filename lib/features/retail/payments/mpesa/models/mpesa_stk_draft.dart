import '../../../../../shared/utils/utils.dart';

class MpesaStkInitiateDraft {
  const MpesaStkInitiateDraft({
    required this.phone,
    required this.amount,
    required this.purpose,
    required this.purposeRef,
    this.accountReference,
    this.description,
  });

  /// E164-ish or local, backend can normalize
  final String phone;

  final num amount;

  /// e.g. "invoice"
  final String purpose;

  /// invoice_id
  final String purposeRef;

  /// Optional override
  final String? accountReference;

  final String? description;

  JsonMap toJson() => <String, dynamic>{
    'phone': phone.trim(),
    'amount': amount,
    'purpose': purpose.trim(),
    'purposeRef': purposeRef.trim(),
    if (accountReference != null && accountReference!.trim().isNotEmpty)
      'accountReference': accountReference!.trim(),
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
  };
}

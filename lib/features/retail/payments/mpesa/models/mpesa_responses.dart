import '../../../../../shared/utils/utils.dart';
import 'mpesa_payment.dart';

class MpesaInitiateResponse {
  const MpesaInitiateResponse({required this.payment});

  final MpesaPayment payment;

  factory MpesaInitiateResponse.fromJson(JsonMap j) =>
      MpesaInitiateResponse(payment: MpesaPayment.fromJson(j));
}

class MpesaStatusResponse {
  const MpesaStatusResponse({required this.payment});

  final MpesaPayment payment;

  factory MpesaStatusResponse.fromJson(JsonMap j) =>
      MpesaStatusResponse(payment: MpesaPayment.fromJson(j));
}

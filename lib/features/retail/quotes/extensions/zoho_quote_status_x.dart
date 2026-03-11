import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';

extension ZohoQuoteStatusX on ZohoQuote {
  /// Normalized Zoho status (lowercase, trimmed)
  String get statusKey => status.trim().toLowerCase();

  bool get isDraft =>
      statusKey.isEmpty || statusKey == 'draft' || statusKey == 'created';

  bool get isSent => statusKey == 'sent';

  bool get isAccepted => statusKey == 'accepted';

  bool get isDeclined => statusKey == 'declined';

  bool get isInvoiced =>
      statusKey == 'invoiced' ||
      statusKey == 'converted_to_invoice' ||
      statusKey == 'converted';

  bool get isExpired => statusKey == 'expired';

  /// ✅ YOUR PRODUCT RULE:
  /// editable until staff confirms & sends (sent == lock point)
  bool get isLocked => !isDraft;

  /// Show "Pay now" once the quote is staff-confirmed (sent) or later.
  /// (Even if you later decide to pay only after invoicing, keep this isolated here.)
  bool get canPayNow => isSent || isAccepted || isInvoiced;

  /// Staff actions
  bool get canStaffConfirmAndSend => isDraft;
  bool get canStaffConvertToInvoice => isSent || isAccepted;
}

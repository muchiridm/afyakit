// lib/features/retail/quotes/models/quote_context.dart

enum QuotePurchaseContext {
  privateUse,
  company;

  /// Existing API values are retained for backward compatibility.
  String get apiValue {
    return switch (this) {
      QuotePurchaseContext.privateUse => 'clinical',
      QuotePurchaseContext.company => 'general',
    };
  }

  String get label {
    return switch (this) {
      QuotePurchaseContext.privateUse => 'Private use',
      QuotePurchaseContext.company => 'Company or organisation',
    };
  }

  String get questionLabel {
    return switch (this) {
      QuotePurchaseContext.privateUse => 'For private use',
      QuotePurchaseContext.company => 'For a company or organisation',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuotePurchaseContext.privateUse => 'Private',
      QuotePurchaseContext.company => 'Company',
    };
  }

  bool get isPrivateUse => this == QuotePurchaseContext.privateUse;

  bool get isCompany => this == QuotePurchaseContext.company;

  bool get requiresPatient => isPrivateUse;

  static QuotePurchaseContext fromApi(Object? value) {
    final String text = (value ?? '').toString().trim().toLowerCase();

    return switch (text) {
      'general' ||
      'company' ||
      'business' ||
      'b2b' => QuotePurchaseContext.company,
      _ => QuotePurchaseContext.privateUse,
    };
  }
}

enum QuotePaymentContext {
  directPay,
  insurance;

  String get apiValue {
    return switch (this) {
      QuotePaymentContext.directPay => 'direct_pay',
      QuotePaymentContext.insurance => 'insurance',
    };
  }

  String get label {
    return switch (this) {
      QuotePaymentContext.directPay => 'Pay directly',
      QuotePaymentContext.insurance => 'Use insurance',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuotePaymentContext.directPay => 'Direct pay',
      QuotePaymentContext.insurance => 'Insurance',
    };
  }

  bool get isDirectPay => this == QuotePaymentContext.directPay;

  bool get isInsurance => this == QuotePaymentContext.insurance;

  bool get requiresMembership => isInsurance;

  bool get requiresPrescription => isInsurance;

  static QuotePaymentContext fromApi(Object? value) {
    final String text = (value ?? '').toString().trim().toLowerCase();

    return switch (text) {
      'insurance' => QuotePaymentContext.insurance,
      _ => QuotePaymentContext.directPay,
    };
  }
}

enum QuoteFulfilmentMethod {
  delivery,
  pickup;

  String get apiValue {
    return switch (this) {
      QuoteFulfilmentMethod.delivery => 'delivery',
      QuoteFulfilmentMethod.pickup => 'pickup',
    };
  }

  String get label {
    return switch (this) {
      QuoteFulfilmentMethod.delivery => 'Delivery',
      QuoteFulfilmentMethod.pickup => 'Pickup',
    };
  }

  String get actionLabel {
    return switch (this) {
      QuoteFulfilmentMethod.delivery => 'Deliver to me',
      QuoteFulfilmentMethod.pickup => 'I will pick up',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuoteFulfilmentMethod.delivery => 'Delivery',
      QuoteFulfilmentMethod.pickup => 'Pickup',
    };
  }

  bool get isDelivery => this == QuoteFulfilmentMethod.delivery;

  bool get isPickup => this == QuoteFulfilmentMethod.pickup;

  bool get requiresLocation => isDelivery;

  static QuoteFulfilmentMethod fromApi(Object? value) {
    final String text = (value ?? '').toString().trim().toLowerCase();

    return switch (text) {
      'pickup' ||
      'pick_up' ||
      'collection' ||
      'collect' => QuoteFulfilmentMethod.pickup,
      _ => QuoteFulfilmentMethod.delivery,
    };
  }
}

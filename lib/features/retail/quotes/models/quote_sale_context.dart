// lib/features/retail/quotes/models/quote_sale_context.dart

enum QuoteSaleContext {
  clinical,
  general;

  String get apiValue {
    return switch (this) {
      QuoteSaleContext.clinical => 'clinical',
      QuoteSaleContext.general => 'general',
    };
  }

  String get label {
    return switch (this) {
      QuoteSaleContext.clinical => 'Clinical / patient sale',
      QuoteSaleContext.general => 'General / OTC / B2B sale',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuoteSaleContext.clinical => 'Clinical',
      QuoteSaleContext.general => 'General',
    };
  }

  bool get isClinical => this == QuoteSaleContext.clinical;

  bool get isGeneral => this == QuoteSaleContext.general;

  bool get requiresPatient => isClinical;

  bool get requiresDeliveryAddress => isClinical;

  static QuoteSaleContext fromApi(Object? value) {
    final String text = (value ?? '').toString().trim().toLowerCase();

    return switch (text) {
      'general' => QuoteSaleContext.general,
      _ => QuoteSaleContext.clinical,
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
      QuotePaymentContext.directPay => 'Direct pay',
      QuotePaymentContext.insurance => 'Insurance',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuotePaymentContext.directPay => 'Direct',
      QuotePaymentContext.insurance => 'Insurance',
    };
  }

  bool get isDirectPay => this == QuotePaymentContext.directPay;

  bool get isInsurance => this == QuotePaymentContext.insurance;

  bool get requiresMembership => isInsurance;

  static QuotePaymentContext fromApi(Object? value) {
    final String text = (value ?? '').toString().trim().toLowerCase();

    return switch (text) {
      'insurance' => QuotePaymentContext.insurance,
      _ => QuotePaymentContext.directPay,
    };
  }
}

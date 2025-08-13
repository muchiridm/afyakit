import 'package:afyakit/features/reports/extensions/stock_expiry_filter_option_enum.dart';

extension ExpiryFilterOptionX on ExpiryFilterOption {
  /// Whether items with no expiry dates should still be included
  bool get allowsNoExpiry => switch (this) {
    ExpiryFilterOption.none => true,
    ExpiryFilterOption.threeMonths => false,
    ExpiryFilterOption.sixMonths => false,
    ExpiryFilterOption.twelveMonths => false,
    ExpiryFilterOption.expiredOnly => false,
  };
}

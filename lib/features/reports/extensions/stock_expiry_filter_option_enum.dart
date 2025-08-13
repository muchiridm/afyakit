enum ExpiryFilterOption {
  none(-1, 'All Dates'),
  expiredOnly(0, 'Expired Only'),
  threeMonths(3, '≤ 3 months'),
  sixMonths(6, '≤ 6 months'),
  twelveMonths(12, '≤ 12 months');

  final int months;
  final String label;

  const ExpiryFilterOption(this.months, this.label);

  static ExpiryFilterOption fromMonths(int months) {
    return ExpiryFilterOption.values.firstWhere(
      (e) => e.months == months,
      orElse: () => ExpiryFilterOption.none,
    );
  }

  bool matches(DateTime expiry) {
    final now = DateTime.now();
    return switch (this) {
      ExpiryFilterOption.none => true,
      ExpiryFilterOption.expiredOnly => expiry.isBefore(now),
      _ => expiry.isBefore(now.add(Duration(days: months * 30))),
    };
  }
}

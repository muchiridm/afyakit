// lib/hq/tenants/extensions/tenant_status_x.dart

/// Canonical tenant status enum.
enum TenantStatus { active, suspended, deleted }

/// Nice helpers + parsing.
extension TenantStatusX on TenantStatus {
  /// Wire-format string (what the backend sends/accepts).
  String get value {
    switch (this) {
      case TenantStatus.active:
        return 'active';
      case TenantStatus.suspended:
        return 'suspended';
      case TenantStatus.deleted:
        return 'deleted';
    }
  }

  bool get isActive => this == TenantStatus.active;
  bool get isSuspended => this == TenantStatus.suspended;
  bool get isDeleted => this == TenantStatus.deleted;

  /// Parse from a (possibly null/dirty) string.
  static TenantStatus parse(
    String? input, {
    TenantStatus fallback = TenantStatus.active,
  }) {
    switch ((input ?? '').trim().toLowerCase()) {
      case 'suspended':
        return TenantStatus.suspended;
      case 'deleted':
        return TenantStatus.deleted;
      case 'active':
        return TenantStatus.active;
      default:
        return fallback;
    }
  }
}

/// Optional: convenience on nullable strings.
extension TenantStatusParsing on String? {
  TenantStatus toTenantStatus({TenantStatus fallback = TenantStatus.active}) =>
      TenantStatusX.parse(this, fallback: fallback);
}

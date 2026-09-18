// lib/core/tenancy/models/tenant_status_x.dart

enum TenantStatus { active, suspended, deleted }

extension TenantStatusX on TenantStatus {
  String get value => switch (this) {
    TenantStatus.active => 'active',
    TenantStatus.suspended => 'suspended',
    TenantStatus.deleted => 'deleted',
  };

  bool get isActive => this == TenantStatus.active;

  bool get isSuspended => this == TenantStatus.suspended;

  bool get isDeleted => this == TenantStatus.deleted;

  static TenantStatus parse(
    String? input, {
    TenantStatus fallback = TenantStatus.active,
  }) {
    return switch ((input ?? '').trim().toLowerCase()) {
      'active' => TenantStatus.active,
      'suspended' => TenantStatus.suspended,
      'deleted' => TenantStatus.deleted,
      _ => fallback,
    };
  }
}

extension TenantStatusParsing on String? {
  TenantStatus toTenantStatus({TenantStatus fallback = TenantStatus.active}) {
    return TenantStatusX.parse(this, fallback: fallback);
  }
}

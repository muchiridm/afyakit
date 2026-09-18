// lib/app/app_identity.dart

enum AppMode { tenant, hq }

/// Bootstrap identity for the running application.
///
/// These values describe HOW this build should start.
///
/// They are intentionally environment-driven rather than Firestore-driven,
/// because they are required before tenant/app configuration can be loaded.
///
/// Example:
///
/// DawaPap:
///   APP=tenant
///   TENANT_ID=afya
///   APP_ID=dawapap
///
/// AfyaTracker:
///   APP=tenant
///   TENANT_ID=afya
///   APP_ID=afyatracker
///
/// HQ:
///   APP=hq
abstract final class AppIdentity {
  const AppIdentity._();

  static const String _rawMode = String.fromEnvironment(
    'APP',
    defaultValue: 'tenant',
  );

  /// Temporary migration default.
  ///
  /// Once all deployment/run configurations explicitly provide TENANT_ID,
  /// we can remove the DawaPap fallback.
  static const String _rawTenantId = String.fromEnvironment(
    'TENANT_ID',
    defaultValue: 'dawapap',
  );

  /// Temporary migration default.
  ///
  /// Once all deployment/run configurations explicitly provide APP_ID,
  /// we can make this mandatory as well.
  static const String _rawAppId = String.fromEnvironment(
    'APP_ID',
    defaultValue: 'dawapap',
  );

  static AppMode get mode {
    switch (_normalize(_rawMode)) {
      case 'hq':
        return AppMode.hq;

      case 'tenant':
      default:
        return AppMode.tenant;
    }
  }

  static String get tenantId {
    final value = _normalize(_rawTenantId);

    return value.isEmpty ? 'dawapap' : value;
  }

  static String get appId {
    final value = _normalize(_rawAppId);

    return value.isEmpty ? 'dawapap' : value;
  }

  static bool get isHq => mode == AppMode.hq;

  static bool get isTenant => mode == AppMode.tenant;

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}

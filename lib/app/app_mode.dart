// lib/app/app_mode.dart

enum AppMode { tenant, hq }

extension AppModeX on AppMode {
  static AppMode fromEnv() {
    const raw = String.fromEnvironment('APP', defaultValue: 'tenant');
    switch (raw.toLowerCase().trim()) {
      case 'hq':
        return AppMode.hq;
      case 'tenant':
      default:
        return AppMode.tenant;
    }
  }

  String get label => this == AppMode.hq ? 'HQ' : 'Tenant';
}

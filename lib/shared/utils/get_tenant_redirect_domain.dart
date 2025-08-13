// lib/shared/utils/get_tenant_redirect_domain.dart

String getTenantRedirectDomain(String tenantId) {
  switch (tenantId) {
    case 'danabtmc':
      return 'https://danabtmc.com';
    case 'dawapap':
      return 'https://dawapap.com';
    default:
      return 'https://afyakit.app'; // fallback or default landing
  }
}

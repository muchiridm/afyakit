part of 'routes.dart';

extension AfyaKitDomainRoutes on AfyaKitRoutes {
  Uri _domainDoc(String tenantId, String domain) =>
      _uriCore('tenants/${_seg(tenantId)}/domains/${_seg(domain)}');

  // List/add (collection)
  Uri listDomains(String tenantId) =>
      _uriCore('tenants/${_seg(tenantId)}/domains');
  Uri addDomain(String tenantId) =>
      _uriCore('tenants/${_seg(tenantId)}/domains');

  // Actions
  Uri verifyDomain(String tenantId, String domain) =>
      _uriCore('tenants/${_seg(tenantId)}/domains/${_seg(domain)}/verify');

  Uri makePrimaryDomain(String tenantId, String domain) =>
      _uriCore('tenants/${_seg(tenantId)}/domains/${_seg(domain)}/primary');

  // Doc endpoints (same URI, different HTTP verbs)
  Uri removeDomain(String tenantId, String domain) =>
      _domainDoc(tenantId, domain);

  /// PATCH /tenants/:tenantId/domains/:domain  (e.g. { active: true/false })
  Uri updateDomain(String tenantId, String domain) =>
      _domainDoc(tenantId, domain);
}

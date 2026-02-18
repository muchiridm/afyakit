part of 'routes.dart';

extension AfyaKitDomainRoutes on AfyaKitRoutes {
  Uri _domainDoc(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}');

  // List/add (collection)
  Uri listDomains(String slug) => _uriCore('tenants/${_seg(slug)}/domains');
  Uri addDomain(String slug) => _uriCore('tenants/${_seg(slug)}/domains');

  // Actions
  Uri verifyDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/verify');

  Uri makePrimaryDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/primary');

  // Doc endpoints (same URI, different HTTP verbs)
  Uri removeDomain(String slug, String domain) => _domainDoc(slug, domain);

  /// PATCH /tenants/:slug/domains/:domain  (e.g. { active: true/false })
  Uri updateDomain(String slug, String domain) => _domainDoc(slug, domain);
}

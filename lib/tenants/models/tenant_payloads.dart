// lib/hq/tenants/models/tenant_payloads.dart
class CreateTenantPayload {
  final String displayName;
  final String? slug;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic> flags;
  final String? ownerUid;
  final String? ownerEmail;
  final List<String> seedAdminUids;

  CreateTenantPayload({
    required this.displayName,
    required this.primaryColor,
    this.slug,
    this.logoPath,
    this.flags = const {},
    this.ownerUid,
    this.ownerEmail,
    this.seedAdminUids = const <String>[],
  });
}

class EditTenantPayload {
  final String? displayName;
  final String? primaryColor;
  final String? logoPath;
  EditTenantPayload({this.displayName, this.primaryColor, this.logoPath});
}

class AddAdminPayload {
  final String uid;
  final String role; // 'admin' | 'manager'
  final String? email;
  final String? displayName;

  AddAdminPayload({
    required this.uid,
    this.role = 'admin',
    this.email,
    this.displayName,
  });
}

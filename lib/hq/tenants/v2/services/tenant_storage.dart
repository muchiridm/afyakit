// lib/hq/tenants/v2/services/tenant_storage.dart

import 'package:firebase_storage/firebase_storage.dart';

/// We still keep this in case you need it elsewhere,
/// but the logo path won't use getDownloadURL anymore.
FirebaseStorage storageForTenant(String tenantSlug) {
  return FirebaseStorage.instance;
}

// lib/shared/api/api_client_base.dart

import 'package:afyakit/shared/config/app_config.dart';

/// Constructs a full base URL for API with tenant
String apiBaseUrl(String tenantId) => '$baseApiUrl/api/$tenantId';

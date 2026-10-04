import 'package:flutter/material.dart';

@immutable
class ZohoAppConfig {
  final bool exists;
  final bool enabled;
  final String connectionId;
  final String? organisationId;
  final String credentialRef;
  final bool credentialConfigured;
  final bool ready;

  const ZohoAppConfig({
    required this.exists,
    required this.enabled,
    required this.connectionId,
    required this.organisationId,
    required this.credentialRef,
    required this.credentialConfigured,
    required this.ready,
  });

  factory ZohoAppConfig.fromMap(Map<String, dynamic> map) {
    return ZohoAppConfig(
      exists: map['exists'] == true,
      enabled: map['enabled'] == true,
      connectionId: map['connectionId']?.toString().trim() ?? '',
      organisationId: _nullableString(map['organisationId']),
      credentialRef: map['credentialRef']?.toString().trim() ?? '',
      credentialConfigured: map['credentialConfigured'] == true,
      ready: map['ready'] == true,
    );
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }
}

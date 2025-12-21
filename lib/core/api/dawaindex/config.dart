import 'package:flutter/foundation.dart';

class DiApiConfig {
  final String baseUrl; // e.g. https://api.example.com or /di-api (web proxy)
  final String? apiKey; // optional: for public key-gated endpoints
  const DiApiConfig({required this.baseUrl, this.apiKey});
}

String _normalizeBase(String v) => v.trim().replaceAll(RegExp(r'/+\$'), '');

const _OVERRIDE_BASE = String.fromEnvironment('DI_API_BASE', defaultValue: '');
const _OVERRIDE_KEY = String.fromEnvironment('DI_API_KEY', defaultValue: '');
const _TARGET = String.fromEnvironment('DI_API_TARGET', defaultValue: 'auto');

const _LOCAL = 'http://localhost:8000';
const _EMU = 'http://10.0.2.2:8000'; // Android emulator → host loopback
const _SIM = 'http://localhost:8000'; // iOS simulator → host loopback
const _CLOUD = 'https://dawaindex-api.onrender.com';
const _WEB = '/di-api'; // Firebase Hosting rewrite (same-origin)

bool _isAndroid() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool _isIOS() => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool _isLocalWebDev() {
  if (!kIsWeb) return false;
  final o = Uri.base.origin;
  return o.startsWith('http://localhost:') || o.startsWith('http://127.0.0.1:');
}

DiApiConfig resolveDiApiBaseForTenant(String tenantId) {
  if (_OVERRIDE_BASE.isNotEmpty) {
    return DiApiConfig(
      baseUrl: _normalizeBase(_OVERRIDE_BASE),
      apiKey: _OVERRIDE_KEY.isNotEmpty ? _OVERRIDE_KEY : null,
    );
  }
  if (kIsWeb) {
    final base = _isLocalWebDev() ? _CLOUD : _WEB;
    return DiApiConfig(
      baseUrl: _normalizeBase(base),
      apiKey: _OVERRIDE_KEY.isNotEmpty ? _OVERRIDE_KEY : 'supersecret7',
    );
  }
  String target = _TARGET.toLowerCase();
  if (target == 'auto') target = kReleaseMode ? 'cloud' : 'local';
  final String base = switch (target) {
    'web-proxy' => _WEB,
    'local' => _isAndroid() ? _EMU : (_isIOS() ? _SIM : _LOCAL),
    'emulator' => _EMU,
    'simulator' => _SIM,
    'cloud' => _CLOUD,
    _ => _CLOUD,
  };
  return DiApiConfig(
    baseUrl: _normalizeBase(base),
    apiKey: _OVERRIDE_KEY.isNotEmpty ? _OVERRIDE_KEY : 'supersecret7',
  );
}

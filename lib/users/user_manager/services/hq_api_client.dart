import 'dart:convert';

import 'package:afyakit/users/user_manager/models/super_admim_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;

class HqApiClient {
  final Uri base; // e.g., Uri.parse('https://your-host/core/hq')
  final fb.FirebaseAuth _auth;

  HqApiClient({required this.base, fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  Future<String> _token() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final token = await user.getIdToken(true); // Future<String?>
    if (token == null || token.isEmpty) {
      // If this ever happens, it usually means the session is stale.
      // You can optionally call await user.reload(); then retry.
      throw StateError('Failed to obtain ID token');
    }
    return token;
  }

  Future<List<SuperAdmin>> listSuperAdmins() async {
    final t = await _token();
    final res = await http.get(
      base.resolve('superadmins'),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (res.statusCode != 200) {
      throw StateError('Failed: ${res.statusCode} ${res.body}');
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    final list = (parsed['users'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SuperAdmin.fromJson)
        .toList();
    return list;
  }

  Future<void> setSuperAdmin({required String uid, required bool value}) async {
    final t = await _token();
    final res = await http.post(
      base.resolve('superadmins/$uid'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: json.encode({'value': value}),
    );
    if (res.statusCode != 200) {
      throw StateError('Failed: ${res.statusCode} ${res.body}');
    }
  }
}

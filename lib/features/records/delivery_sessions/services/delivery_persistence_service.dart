import 'dart:convert';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_state.dart';

class DeliveryPersistenceService {
  static const _prefsKey = 'delivery_session_state';

  static CollectionReference<Map<String, dynamic>> _collection(
    String tenantId,
  ) {
    return db
        .collection('tenants')
        .doc(tenantId)
        .collection('delivery_sessions_temp');
  }

  // ─────────────────────────────────────────────
  // 📦 Save session (SharedPrefs + Firestore)
  // ─────────────────────────────────────────────
  static Future<void> persistAll(
    String tenantId,
    DeliverySessionState state,
  ) async {
    await _persistToPrefs(state);
    await _persistToFirestore(tenantId, state);
  }

  // ─────────────────────────────────────────────
  // ♻️ Restore session (prefs → fallback to Firestore)
  // ─────────────────────────────────────────────
  static Future<DeliverySessionState?> restoreState(String tenantId) async {
    final cached = await _restoreFromPrefs();
    if (cached != null) return cached;

    final doc = await _collection(tenantId).doc(_guessDeliveryId()).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return DeliverySessionState(
      deliveryId: data['delivery_id'],
      enteredByName: data['entered_by_name'],
      enteredByEmail: data['entered_by_email'],
      sources: List<String>.from(data['sources'] ?? []),
    );
  }

  // ─────────────────────────────────────────────
  // 🧼 Clear session (SharedPrefs + Firestore)
  // ─────────────────────────────────────────────
  static Future<void> clearAll(String tenantId, String deliveryId) async {
    await _clearPrefs();
    await _finalizeAndDeleteFirestoreBackup(tenantId, deliveryId);
  }

  // ─────────────────────────────────────────────
  // 🔒 Private helpers
  // ─────────────────────────────────────────────
  static Future<void> _persistToPrefs(DeliverySessionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'deliveryId': state.deliveryId,
        'enteredByName': state.enteredByName,
        'enteredByEmail': state.enteredByEmail,
        'sources': state.sources,
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
      debugPrint('✅ Session saved to prefs: ${state.deliveryId}');
    } catch (e, st) {
      debugPrint('❌ Failed to persist to prefs: $e\n$st');
    }
  }

  static Future<DeliverySessionState?> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return null;

      final map = jsonDecode(raw);
      return DeliverySessionState(
        deliveryId: map['deliveryId'],
        enteredByName: map['enteredByName'],
        enteredByEmail: map['enteredByEmail'],
        sources: List<String>.from(map['sources'] ?? []),
      );
    } catch (e, st) {
      debugPrint('❌ Failed to restore from prefs: $e\n$st');
      return null;
    }
  }

  static Future<void> _clearPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('🧹 Cleared session from prefs.');
    } catch (e, st) {
      debugPrint('❌ Failed to clear prefs: $e\n$st');
    }
  }

  static Future<void> _persistToFirestore(
    String tenantId,
    DeliverySessionState state,
  ) async {
    try {
      final doc = _collection(tenantId).doc(state.deliveryId);
      await doc.set({
        'delivery_id': state.deliveryId,
        'entered_by_name': state.enteredByName,
        'entered_by_email': state.enteredByEmail,
        'sources': state.sources,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'is_finalized': false,
        'expires_at': null,
        'batches_count': 0,
      }, SetOptions(merge: true));
      debugPrint('📤 Session saved to Firestore → ${state.deliveryId}');
    } catch (e, st) {
      debugPrint('❌ Failed to persist to Firestore: $e\n$st');
    }
  }

  static Future<void> _finalizeAndDeleteFirestoreBackup(
    String tenantId,
    String deliveryId,
  ) async {
    try {
      final doc = _collection(tenantId).doc(deliveryId);
      await doc.set({
        'is_finalized': true,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      }, SetOptions(merge: true));
      await doc.delete();
      debugPrint('🗑️ Firestore backup cleared for: $deliveryId');
    } catch (e, st) {
      debugPrint('❌ Failed to clear Firestore backup: $e\n$st');
    }
  }

  static String _guessDeliveryId() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'DN_$y$m${d}_001'; // fallback
  }
}

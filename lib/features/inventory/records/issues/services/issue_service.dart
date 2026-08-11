// lib/features/inventory/records/issues/services/issue_service.dart

import 'dart:convert';

import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/auth_session/providers/token_provider.dart';

import 'package:afyakit/features/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final issueServiceProvider = Provider<IssueService>((ref) {
  final tp = ref.read(tokenProvider);
  return IssueService(tp);
});

class IssueService {
  final TokenProvider tokenProvider;

  IssueService(this.tokenProvider);

  // ─────────────────────────────────────────────
  // HTTP
  // ─────────────────────────────────────────────

  Map<String, String> _headers(String token, String tenantId) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'x-tenant-id': tenantId,
  };

  Never _throwHttp(String operation, http.Response response) {
    String message = response.body;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        message =
            decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            response.body;
      }
    } catch (_) {
      // Keep raw response body.
    }

    throw Exception(
      '❌ $operation failed '
      '[${response.statusCode}]: $message',
    );
  }

  Map<String, dynamic> _decodeObject(String operation, http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('$operation returned an invalid response.');
    }

    return decoded;
  }

  IssueRecord _recordFromMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString().trim();

    if (id.isEmpty) {
      throw StateError('Issue payload is missing id.');
    }

    return IssueRecord.fromMap(id, data);
  }

  IssueRecord _recordFromMutationResponse(
    String operation,
    http.Response response,
  ) {
    final body = _decodeObject(operation, response);

    final rawRecord = body['record'];

    if (rawRecord is! Map) {
      throw StateError('$operation response is missing record.');
    }

    return _recordFromMap(Map<String, dynamic>.from(rawRecord));
  }

  // ─────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────

  Future<String> createIssueWithEntriesIdempotent({
    required String tenantId,
    required String requestKey,
    required IssueRecord issueDraft,
    required List<IssueEntry> entries,
  }) async {
    final cleanTenantId = tenantId.trim();

    if (cleanTenantId.isEmpty) {
      throw ArgumentError('tenantId must not be empty');
    }

    if (requestKey.trim().isEmpty) {
      throw ArgumentError('requestKey must not be empty');
    }

    if (entries.isEmpty) {
      throw ArgumentError('Issue must contain at least one entry.');
    }

    final token = await tokenProvider.getToken();
    final uri = AfyaKitRoutes(cleanTenantId).issues();

    final body = <String, dynamic>{
      'requestKey': requestKey.trim(),

      'fromStore': issueDraft.fromStore.trim(),
      'toStore': issueDraft.toStore.trim(),

      'type': issueDraft.type.name,

      if (issueDraft.note != null && issueDraft.note!.trim().isNotEmpty)
        'note': issueDraft.note!.trim(),

      'entries': entries.map(_entryToApiMap).toList(),
    };

    if (kDebugMode) {
      debugPrint('🚀 POST $uri');
      debugPrint('📦 ${jsonEncode(body)}');
    }

    final response = await http.post(
      uri,
      headers: _headers(token, cleanTenantId),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      _throwHttp('createIssueWithEntriesIdempotent', response);
    }

    final data = _decodeObject('createIssueWithEntriesIdempotent', response);

    final record = _recordFromMap(data);

    if (kDebugMode) {
      debugPrint('✅ issue created: ${record.id}');
    }

    return record.id;
  }

  Map<String, dynamic> _entryToApiMap(IssueEntry entry) {
    return <String, dynamic>{
      'itemId': entry.itemId.trim(),
      'itemType': entry.itemType.name,
      'itemName': entry.itemName.trim(),
      'itemGroup': entry.itemGroup.trim(),

      if (entry.strength != null) 'strength': entry.strength,
      if (entry.size != null) 'size': entry.size,
      if (entry.formulation != null) 'formulation': entry.formulation,
      if (entry.packSize != null) 'packSize': entry.packSize,

      'itemTypeLabel': entry.itemTypeLabel,

      if (entry.batchId != null && entry.batchId!.trim().isNotEmpty)
        'batchId': entry.batchId!.trim(),

      'quantity': entry.quantity,

      if (entry.brand != null && entry.brand!.trim().isNotEmpty)
        'brand': entry.brand!.trim(),

      if (entry.expiry != null) 'expiry': entry.expiry!.toIso8601String(),

      // Until IssueEntry itself carries this explicitly,
      // issues originate from store stock.
      'locationType': 'stores',
    };
  }

  // ─────────────────────────────────────────────
  // Reads
  // ─────────────────────────────────────────────

  Future<List<IssueRecord>> getAllIssues(String tenantId) async {
    final cleanTenantId = tenantId.trim();

    final token = await tokenProvider.getToken();
    final uri = AfyaKitRoutes(cleanTenantId).issues();

    if (kDebugMode) {
      debugPrint('📥 GET $uri');
    }

    final response = await http.get(
      uri,
      headers: _headers(token, cleanTenantId),
    );

    if (response.statusCode != 200) {
      _throwHttp('getAllIssues', response);
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw StateError('getAllIssues returned an invalid response.');
    }

    return decoded
        .whereType<Map>()
        .map((raw) => _recordFromMap(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<IssueRecord> getIssue(String tenantId, String issueId) async {
    final cleanTenantId = tenantId.trim();
    final cleanIssueId = issueId.trim();

    final token = await tokenProvider.getToken();

    final uri = AfyaKitRoutes(cleanTenantId).issueById(cleanIssueId);

    final response = await http.get(
      uri,
      headers: _headers(token, cleanTenantId),
    );

    if (response.statusCode != 200) {
      _throwHttp('getIssue', response);
    }

    return _recordFromMap(_decodeObject('getIssue', response));
  }

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  Future<IssueRecord> approve(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'approveIssue',
      uri: AfyaKitRoutes(tenantId).approveIssue(issueId),
    );
  }

  Future<IssueRecord> reject(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'rejectIssue',
      uri: AfyaKitRoutes(tenantId).rejectIssue(issueId),
    );
  }

  Future<IssueRecord> cancel(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'cancelIssue',
      uri: AfyaKitRoutes(tenantId).cancelIssue(issueId),
    );
  }

  Future<IssueRecord> issue(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'issueStock',
      uri: AfyaKitRoutes(tenantId).issueStock(issueId),
    );
  }

  Future<IssueRecord> receive(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'receiveIssue',
      uri: AfyaKitRoutes(tenantId).receiveIssue(issueId),
    );
  }

  Future<IssueRecord> dispose(String tenantId, String issueId) {
    return _postAction(
      tenantId: tenantId,
      issueId: issueId,
      operation: 'disposeIssue',
      uri: AfyaKitRoutes(tenantId).disposeIssue(issueId),
    );
  }

  Future<IssueRecord> dispense(
    String tenantId,
    String issueId, {
    String reason = 'Dispensed',
  }) async {
    final cleanTenantId = tenantId.trim();

    final token = await tokenProvider.getToken();

    final uri = AfyaKitRoutes(cleanTenantId).dispenseIssue(issueId);

    final response = await http.post(
      uri,
      headers: _headers(token, cleanTenantId),
      body: jsonEncode({
        'reason': reason.trim().isEmpty ? 'Dispensed' : reason.trim(),
      }),
    );

    if (response.statusCode != 200) {
      _throwHttp('dispenseIssue', response);
    }

    return _recordFromMutationResponse('dispenseIssue', response);
  }

  Future<IssueRecord> _postAction({
    required String tenantId,
    required String issueId,
    required String operation,
    required Uri uri,
  }) async {
    final cleanTenantId = tenantId.trim();

    final token = await tokenProvider.getToken();

    if (kDebugMode) {
      debugPrint('🚀 POST $uri');
    }

    final response = await http.post(
      uri,
      headers: _headers(token, cleanTenantId),
    );

    if (response.statusCode != 200) {
      _throwHttp(operation, response);
    }

    return _recordFromMutationResponse(operation, response);
  }
}

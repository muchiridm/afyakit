import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/api/api_client.dart';

class ApiTestScreen extends ConsumerStatefulWidget {
  const ApiTestScreen({super.key});

  @override
  ConsumerState<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends ConsumerState<ApiTestScreen> {
  final _itemIdController = TextEditingController();
  String _log = '';
  bool _loading = false;

  static const _itemTypes = ['medication', 'consumable', 'equipment'];

  void _logLine(String line) {
    setState(() => _log += '$line\n');
  }

  Future<void> runTests(ApiClient client) async {
    setState(() {
      _loading = true;
      _log = '';
    });

    final itemId = _itemIdController.text.trim();

    try {
      final ping = await client.dio.get('/ping');
      _logLine('✅ /ping → ${ping.statusCode}');
      _logLine(const JsonEncoder.withIndent('  ').convert(ping.data));
    } catch (e, st) {
      _logLine('❌ Ping failed: $e\n$st');
    }

    if (itemId.isNotEmpty) {
      try {
        final res = await client.dio.get('/inventory/$itemId');
        _logLine('📦 /inventory/$itemId → ${res.statusCode}');
        _logLine(const JsonEncoder.withIndent('  ').convert(res.data));
      } catch (e, st) {
        _logLine('❌ Failed to get item: $e\n$st');
      }
    }

    setState(() => _loading = false);
  }

  Future<void> searchItemById(ApiClient client) async {
    setState(() {
      _loading = true;
      _log = '';
    });

    final targetId = _itemIdController.text.trim();

    for (final type in _itemTypes) {
      try {
        final res = await client.dio.get(
          '/inventory',
          queryParameters: {'type': type},
        );

        final List items = res.data;

        for (final item in items) {
          final map = Map<String, dynamic>.from(item);
          final internalId = map['id']?.toString() ?? 'null';
          final docId = map['docId']?.toString() ?? '(unknown)';

          if (internalId == targetId || docId == targetId) {
            _logLine('✅ Found in "$type":');
            _logLine('- 🔑 docId: $docId');
            _logLine('- 🆔 id: $internalId');
            _logLine(const JsonEncoder.withIndent('  ').convert(map));
            setState(() => _loading = false);
            return;
          }
        }
      } catch (e, st) {
        _logLine('❌ Error in "$type": $e\n$st');
      }
    }

    _logLine('🕵️‍♂️ Not found in any inventory collection.');
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final apiClientAsync = ref.watch(apiClientProvider);

    return apiClientAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) =>
          Scaffold(body: Center(child: Text('❌ API Client error: $e'))),
      data: (client) => Scaffold(
        appBar: AppBar(title: const Text('API Tester')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildTesterUI(client),
        ),
      ),
    );
  }

  Widget _buildTesterUI(ApiClient client) {
    return Column(
      children: [
        TextField(
          controller: _itemIdController,
          decoration: const InputDecoration(labelText: 'Item ID'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () => runTests(client),
                child: const Text('Run Tests'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () => searchItemById(client),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: const Text('Search All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_log, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      ],
    );
  }
}

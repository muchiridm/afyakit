import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_test_controller.dart';

class ApiTestScreen extends ConsumerWidget {
  const ApiTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(apiTestControllerProvider);
    final ctrl = ref.read(apiTestControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('API Tester')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Item ID / docId
            TextField(
              decoration: const InputDecoration(
                labelText: 'Item ID (or docId)',
                hintText: 'e.g. 584f89db-… or firestore doc id',
              ),
              onChanged: ctrl.setItemId,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.loading ? null : ctrl.runTests,
                    child: const Text('Run Tests'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.loading
                        ? null
                        : ctrl.searchItemAcrossTypes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                    child: const Text('Search Item Across Types'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Batch ID
            TextField(
              decoration: const InputDecoration(
                labelText: 'Batch ID',
                hintText: 'e.g. PIaGhrg9ndeSKxfHuVGR',
              ),
              onChanged: ctrl.setBatchId,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: state.loading ? null : ctrl.searchBatchId,
                icon: const Icon(Icons.vpn_key),
                label: const Text('Search Batch'),
              ),
            ),
            const SizedBox(height: 12),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    state.logLines.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

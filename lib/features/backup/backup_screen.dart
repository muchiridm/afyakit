import 'package:afyakit/features/backup/backup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // kIsWeb

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final Map<String, String> collectionLabels = {
    'users': 'App Users',
    'stores': 'Stores',
    'locations': 'Locations',
    'medications': 'Medications',
    'consumables': 'Consumables',
    'preferences': 'Preferences',
    'issues': 'Issue Records',
  };

  String selected = 'All';
  bool _includeSubcollections = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(backupControllerProvider);

    return AppPage(
      maxWidth: 800,
      scrollable: false,
      header: const AppHeader(title: 'Backup Firestore'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(),
                    const SizedBox(height: 16),
                    _buildSubcollectionToggle(),
                    const SizedBox(height: 24),
                    _buildBackupButton(),
                    const SizedBox(height: 16),
                    if (kIsWeb) _buildWebHint(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: ['All', ...collectionLabels.keys].contains(selected)
          ? selected
          : null,
      decoration: const InputDecoration(
        labelText: 'Select Collection',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: 'All', child: Text('All Collections')),
        ...collectionLabels.entries.map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ),
      ],
      onChanged: (val) {
        if (val != null) setState(() => selected = val);
      },
    );
  }

  Widget _buildSubcollectionToggle() {
    return CheckboxListTile(
      title: const Text('Include Subcollections'),
      value: _includeSubcollections,
      onChanged: (val) {
        if (val != null) setState(() => _includeSubcollections = val);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildBackupButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('Start Backup'),
      onPressed: _onBackupPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  void _onBackupPressed() {
    final controller = ref.read(backupControllerProvider.notifier);
    controller.runBackup(
      selected: selected,
      includeSubcollections: _includeSubcollections,
      labels: collectionLabels,
    );
  }

  Widget _buildWebHint() {
    return const Text(
      '📁 If download doesn’t appear, check browser pop-up settings or Downloads folder.',
      style: TextStyle(color: Colors.grey),
      textAlign: TextAlign.center,
    );
  }
}

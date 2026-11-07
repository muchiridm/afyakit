import 'package:afyakit/features/records/campaigns/models/campaign.dart';
import 'package:afyakit/features/records/campaigns/providers/campaigns_providers.dart';
import 'package:afyakit/features/records/campaigns/services/campaigns_service.dart';
import 'package:afyakit/features/records/campaigns/widgets/campaign_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared staff screen. The AfyaKitClient automatically scopes requests to
/// the active application; never override x-app-id from a widget.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCampaigns = ref.watch(campaignsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns'), actions: [
        IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(campaignsProvider)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('New campaign'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const CampaignEditorScreen())),
      ),
      body: asyncCampaigns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Unable to load campaigns: $e', textAlign: TextAlign.center),
            TextButton(onPressed: () => ref.invalidate(campaignsProvider),
              child: const Text('Retry')),
          ]))),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No campaigns yet. Create your first campaign.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final campaign = items[index];
                  return ListTile(
                    title: Text(campaign.name),
                    subtitle: Text('${_label(campaign.examType)} · ${campaign.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => CampaignDetailScreen(campaignId: campaign.id))),
                  );
                },
              ),
      ),
    );
  }
}

String _label(String type) => switch (type) {
  'pre_employment' => 'Pre-employment',
  'periodic' => 'Periodic examination',
  'exit' => 'Exit examination',
  'return_to_work' => 'Return to work',
  'wellness' => 'Wellness',
  _ => type,
};

class CampaignDetailScreen extends ConsumerStatefulWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});
  final String campaignId;
  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  Campaign? _campaign;
  String? _token;
  bool _working = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = await ref.read(campaignsServiceProvider.future);
      final campaign = await svc.get(widget.campaignId);
      if (mounted) setState(() { _campaign = campaign; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _status(String status) async {
    setState(() => _working = true);
    try {
      final svc = await ref.read(campaignsServiceProvider.future);
      final updated = await svc.setStatus(widget.campaignId, status);
      if (mounted) setState(() { _campaign = updated; _token = updated.publicToken; _error = null; });
      ref.invalidate(campaignsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign details'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (c == null && _error == null) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text('Request failed: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (c != null) ...[
          Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${_label(c.examType)} · ${c.status}'),
          if (c.organisationId != null) Text('Organisation: ${c.organisationId}'),
          if (c.location != null) Text('Location: ${c.location}'),
          const SizedBox(height: 24),
          if (_working) const LinearProgressIndicator(),
          if (c.status == 'draft' || c.status == 'closed')
            FilledButton(onPressed: _working ? null : () => _status('open'),
              child: const Text('Open registration')),
          if (c.status == 'open')
            OutlinedButton(onPressed: _working ? null : () => _status('closed'),
              child: const Text('Close registration')),
          if (c.status == 'closed' || c.status == 'draft')
            OutlinedButton(onPressed: _working ? null : () => _status('archived'),
              child: const Text('Archive campaign')),
          if (_token != null) ...[
            const SizedBox(height: 16),
            const Text('Registration token — copy now. It will not be returned again.'),
            SelectableText(_token!),
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _token!)),
              icon: const Icon(Icons.copy), label: const Text('Copy token')),
            const Text('Public participant web URL and QR code require the configured FE registration route.'),
          ],
          if (c.publicLinkEnabled && _token == null)
            const Padding(padding: EdgeInsets.only(top: 16), child: Text(
              'Registration link is active. Its raw token is not returned on GET; keep the original link secure.' )),
        ],
      ]),
    );
  }
}

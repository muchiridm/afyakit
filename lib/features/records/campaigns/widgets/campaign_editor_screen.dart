import 'package:afyakit/features/records/campaigns/models/campaign.dart';
import 'package:afyakit/features/records/campaigns/providers/campaigns_providers.dart';
import 'package:afyakit/features/records/campaigns/services/campaigns_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignEditorScreen extends ConsumerStatefulWidget {
  const CampaignEditorScreen({super.key});
  @override
  ConsumerState<CampaignEditorScreen> createState() =>
      _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends ConsumerState<CampaignEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  String _type = 'periodic';
  String? _orgId;
  String? _templateId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final templates = await ref.read(campaignQuestionnairesProvider.future);
      final selected = templates.where((t) => t.id == _templateId).firstOrNull;
      final service = await ref.read(campaignsServiceProvider.future);
      final result = await service.create(
        CampaignDraft(
          name: _name.text,
          examType: _type,
          organisationId: _orgId,
          location: _location.text,
          questionnaire: selected == null
              ? null
              : CampaignQuestionnaireAssignment(
                  templateId: selected.id,
                  version: selected.latestVersion,
                ),
        ),
      );
      ref.invalidate(campaignsProvider);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create campaign: $e')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(campaignOrganisationsProvider);
    final templates = ref.watch(campaignQuestionnairesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New campaign')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Campaign name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Campaign type'),
              items: const [
                DropdownMenuItem(
                  value: 'pre_employment',
                  child: Text('Pre-employment'),
                ),
                DropdownMenuItem(
                  value: 'periodic',
                  child: Text('Periodic examination'),
                ),
                DropdownMenuItem(
                  value: 'exit',
                  child: Text('Exit examination'),
                ),
                DropdownMenuItem(
                  value: 'return_to_work',
                  child: Text('Return to work'),
                ),
                DropdownMenuItem(value: 'wellness', child: Text('Wellness')),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? _type;
                if (_type == 'wellness') _orgId = null;
              }),
            ),
            const SizedBox(height: 16),
            orgs.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load organisations: $e'),
              data: (contacts) => DropdownButtonFormField<String>(
                initialValue: _orgId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _type == 'wellness'
                      ? 'Organisation (optional)'
                      : 'Organisation',
                ),
                items: [
                  if (_type == 'wellness')
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No organisation'),
                    ),
                  ...contacts.map(
                    (c) => DropdownMenuItem(
                      value: c.accountNumber,
                      child: Text(
                        c.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _orgId = value),
                validator: (v) => _type != 'wellness' && v == null
                    ? 'Select an organisation'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
              ),
            ),
            const SizedBox(height: 16),
            templates.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load questionnaires: $e'),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _templateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Published registration questionnaire',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Assign later'),
                  ),
                  ...items.map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        '${t.title} (v${t.latestVersion})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _templateId = v),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Campaign is created as a draft. A required general questionnaire must be assigned before publishing.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving || orgs.isLoading || templates.isLoading
                  ? null
                  : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Create draft'),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/features/occupational_health/widgets/occupational_health_dashboard_screen.dart
import 'package:flutter/material.dart';

enum OhSection { overview, campaigns, medex, certificates, reports }

/// Occupational Health landing page.
///
/// Navigation shell only. Campaign/MedEx API endpoints exist, but their
/// data-backed Flutter screens still need to be implemented and wired here.
/// Do not treat this screen as a clinical record or a data source.
class OccupationalHealthDashboardScreen extends StatefulWidget {
  const OccupationalHealthDashboardScreen({
    super.key,
    this.initialSection = OhSection.overview,
  });

  final OhSection initialSection;

  @override
  State<OccupationalHealthDashboardScreen> createState() =>
      _OccupationalHealthDashboardScreenState();
}

class _OccupationalHealthDashboardScreenState
    extends State<OccupationalHealthDashboardScreen> {
  late OhSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Occupational Health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Occuwell', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Campaign management, occupational examinations and fitness decisions.'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final section in OhSection.values)
                ChoiceChip(
                  selected: _section == section,
                  label: Text(_label(section)),
                  onSelected: (_) => setState(() => _section = section),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_section == OhSection.overview) ...[
            _menuCard(
              context,
              icon: Icons.campaign_outlined,
              title: 'Campaigns',
              subtitle: 'Employer programmes, questionnaires and submissions',
              section: OhSection.campaigns,
            ),
            _menuCard(
              context,
              icon: Icons.medical_services_outlined,
              title: 'MedEx',
              subtitle: 'Examinations, clinical checklists and sign-off',
              section: OhSection.medex,
            ),
            _menuCard(
              context,
              icon: Icons.verified_outlined,
              title: 'Fitness certificates',
              subtitle: 'Issued fitness decisions and certificates',
              section: OhSection.certificates,
            ),
            _menuCard(
              context,
              icon: Icons.assessment_outlined,
              title: 'Reports',
              subtitle: 'Employer summaries and occupational surveillance',
              section: OhSection.reports,
            ),
          ] else
            _sectionDetails(context, _section),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required OhSection section,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _section = section),
      ),
    );
  }

  Widget _sectionDetails(BuildContext context, OhSection section) {
    final explanation = switch (section) {
      OhSection.campaigns =>
        'Campaign list, employer details, questionnaires, registration and submissions.',
      OhSection.medex =>
        'MedEx list, individual examinations, evidence checklist, fitness assessment and sign-off.',
      OhSection.certificates =>
        'Signed fitness certificates and their PDF exports.',
      OhSection.reports =>
        'Occupational health reports and aggregate, access-controlled employer summaries.',
      OhSection.overview => '',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label(section), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(explanation),
            const SizedBox(height: 12),
            const Text(
              'The navigation section is ready. Connect the data-backed '
              'Flutter list/detail screens before enabling live operations.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  String _label(OhSection section) => switch (section) {
        OhSection.overview => 'Overview',
        OhSection.campaigns => 'Campaigns',
        OhSection.medex => 'MedEx',
        OhSection.certificates => 'Certificates',
        OhSection.reports => 'Reports',
      };
}

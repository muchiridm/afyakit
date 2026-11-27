// lib/features/records/health_profiles/widgets/profile_app_access_section.dart
// Presentation and confirmation only; all mutations use ProfilesController.
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:material_ui/material_ui.dart';

class ProfileAppAccessSection extends StatelessWidget {
  const ProfileAppAccessSection({
    super.key,
    required this.profile,
    required this.currentAppId,
    required this.controller,
    required this.busy,
  });

  final Profile profile;
  final String currentAppId;
  final ProfilesController controller;
  final bool busy;

  Future<void> _add(BuildContext context) async {
    var destination = '';
    var account = '';
    var approval = '';
    final values = await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to application'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('An approved patient or representative release must already exist. This dialog does not create approval.'),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => destination = value.trim().toLowerCase(),
                  decoration: const InputDecoration(labelText: 'Destination app ID', hintText: 'afyatracker'),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => account = value.trim(),
                  decoration: const InputDecoration(labelText: 'Linked Native Contact account number', hintText: 'AC-XXXXXX'),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => approval = value.trim(),
                  decoration: const InputDecoration(labelText: 'Approved release reference'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(destination) ||
                  destination == currentAppId.trim().toLowerCase() ||
                  profile.appIds.contains(destination) ||
                  account.isEmpty || approval.isEmpty) return;
              Navigator.pop(dialogContext, (destination, account, approval));
            },
            child: const Text('Add to app'),
          ),
        ],
      ),
    );
    if (values == null || !context.mounted) return;
    try {
      await controller.addAppEnrolment(
        profileId: profile.profileId,
        destinationAppId: values.$1,
        accountNumber: values.$2,
        authorizationReference: values.$3,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to ${values.$1}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not add this app. Check the approved release, contact enrolment and app permissions.'),
        ));
      }
    }
  }

  Future<void> _remove(BuildContext context, String appId) async {
    var reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $appId?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This removes profile access from the selected app. The canonical profile and retained clinical records will not be deleted.'),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => reasonText = value.trim(),
              maxLength: 512,
              decoration: const InputDecoration(labelText: 'Reason for removal'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (reasonText.isEmpty) return;
              Navigator.pop(dialogContext, reasonText);
            },
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await controller.removeAppEnrolment(
        profileId: profile.profileId, targetAppId: appId, reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $appId access')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to remove app access. Please check your permissions.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = currentAppId.trim().toLowerCase();
    final enrolled = profile.appIds.toSet().toList()..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Application access', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Only enrolled applications can see this Health Profile through profile endpoints.'),
            const SizedBox(height: 12),
            for (final app in enrolled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apps_outlined),
                title: Text(app),
                subtitle: Text(app == current ? 'Current application' : 'Enrolled'),
                trailing: app == current
                    ? const Text('Current app')
                    : TextButton.icon(
                        onPressed: busy ? null : () => _remove(context, app),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Remove'),
                      ),
              ),
            if (enrolled.isEmpty) const Text('No application enrolments found.'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy || !profile.isActive ? null : () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Add to app'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

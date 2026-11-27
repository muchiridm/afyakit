// lib/features/records/health_profiles/widgets/profile_self_app_access_section.dart
// Owner self-service UI. Consent and app eligibility come from the backend.
// Staff access administration stays in ProfileAppAccessSection.

import 'package:dio/dio.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_app_access_section.dart';
import 'package:material_ui/material_ui.dart';

class ProfileSelfAppAccessSection extends StatefulWidget {
  const ProfileSelfAppAccessSection({
    super.key,
    required this.profile,
    required this.currentAppId,
    required this.controller,
    required this.busy,
    this.staffFallback = false,
  });

  final Profile profile;
  final String currentAppId;
  final ProfilesController controller;
  final bool busy;
  final bool staffFallback;

  @override
  State<ProfileSelfAppAccessSection> createState() =>
      _ProfileSelfAppAccessSectionState();
}

class _ProfileSelfAppAccessSectionState
    extends State<ProfileSelfAppAccessSection> {
  ProfileSharingOptions? _options;
  bool _loading = true;
  bool _notOwner = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileSelfAppAccessSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.profileId != widget.profile.profileId ||
        oldWidget.currentAppId != widget.currentAppId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  bool _isForbidden(Object error) => error is DioException &&
      (error.response?.statusCode == 403 || error.response?.statusCode == 404);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _notOwner = false;
      _error = null;
    });
    try {
      final options = await widget.controller.eligibleOwnApps(widget.profile.profileId);
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notOwner = _isForbidden(error);
        _error = _notOwner ? null : 'Could not load application access. Try again.';
      });
    }
  }

  Future<void> _share() async {
    final options = _options;
    if (options == null || _working || widget.busy) return;
    final candidates = options.apps.where((app) => !app.enrolled &&
        !widget.profile.appIds.contains(app.appId)).toList(growable: false);
    if (candidates.isEmpty) return;

    String? selectedApp;
    var accepted = false;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Share Health Profile'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Choose an application:'),
                  const SizedBox(height: 8),
                  for (final app in candidates)
                    RadioListTile<String>(
                      title: Text(app.appId),
                      value: app.appId,
                      groupValue: selectedApp,
                      onChanged: (value) => update(() => selectedApp = value),
                    ),
                  const Divider(height: 24),
                  const Text('Before sharing', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(options.consentNotice),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: (value) => update(() => accepted = value == true),
                    title: const Text('I understand and authorize this sharing.'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: accepted && selectedApp != null
                  ? () => Navigator.pop(dialogContext, selectedApp)
                  : null,
              child: const Text('Share profile'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.controller.shareOwnProfile(
        profileId: widget.profile.profileId,
        destinationAppId: choice,
        consentVersion: options.consentVersion,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile shared with $choice')),
      );
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not share the profile. Please check your app access and try again.'),
      ));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(String appId) async {
    if (_working || widget.busy || appId == widget.currentAppId.trim().toLowerCase()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $appId access?'),
        content: const Text(
          'This app will no longer have access to this Health Profile. '
          'Existing clinical records retained under legal requirements are not deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove access')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.controller.revokeOwnProfileApp(
        profileId: widget.profile.profileId, targetAppId: appId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $appId access')),
      );
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to remove application access. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notOwner) {
      if (widget.staffFallback) {
        return ProfileAppAccessSection(
          profile: widget.profile,
          currentAppId: widget.currentAppId,
          controller: widget.controller,
          busy: widget.busy,
        );
      }
      return const SizedBox.shrink();
    }
    final current = widget.currentAppId.trim().toLowerCase();
    final enrolled = widget.profile.appIds.toSet().toList()..sort();
    final eligible = _options?.apps.where((app) => !app.enrolled &&
        !enrolled.contains(app.appId)).toList(growable: false) ?? const <EligibleProfileApp>[];
    final disabled = _working || widget.busy || _loading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Application access', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Choose which applications can access this profile.'),
            if (_loading) const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            const SizedBox(height: 8),
            for (final app in enrolled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apps_outlined),
                title: Text(app),
                subtitle: Text(app == current ? 'Current application' : 'Enrolled'),
                trailing: app == current
                    ? const Text('Current app')
                    : TextButton.icon(
                        onPressed: disabled || _options == null ? null : () => _remove(app),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Remove'),
                      ),
              ),
            if (eligible.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : _share,
                  icon: const Icon(Icons.add),
                  label: const Text('Add to app'),
                ),
              )
            else if (!_loading && _options != null)
              const Text('No additional eligible applications.'),
          ],
        ),
      ),
    );
  }
}

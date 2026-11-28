// lib/features/records/health_profiles/widgets/profile_self_app_access_section.dart
// Owner self-service UI. Consent and app eligibility come from the backend.
// Staff access administration stays in ProfileAppAccessSection.

import 'package:dio/dio.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';

import 'package:material_ui/material_ui.dart';

class ProfileSelfAppAccessSection extends StatefulWidget {
  const ProfileSelfAppAccessSection({
    super.key,
    this.profile,
    this.profileId,
    required this.currentAppId,
    required this.controller,
    required this.busy,
    this.staffFallback = false,
    this.onChanged,
  });

  final Profile? profile;
  final String? profileId;
  String get id => profileId ?? profile!.profileId;
  final String currentAppId;
  final ProfilesController controller;
  final bool busy;
  final bool staffFallback;
  final VoidCallback? onChanged;

  @override
  State<ProfileSelfAppAccessSection> createState() =>
      _ProfileSelfAppAccessSectionState();
}

class _ProfileSelfAppAccessSectionState
    extends State<ProfileSelfAppAccessSection> {
  ProfileSharingOptions? _options;
  int _request = 0;
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
    if (oldWidget.id != widget.id ||
        oldWidget.currentAppId != widget.currentAppId ||
        oldWidget.controller != widget.controller) {
      _options = null;
      _working = false;
      _loading = true;
      ++_request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  bool _isForbidden(Object error) =>
      error is DioException &&
      (error.response?.statusCode == 403 || error.response?.statusCode == 404);

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _notOwner = false;
      _error = null;
      _options = null;
    });
    try {
      final options = await widget.controller.eligibleOwnApps(widget.id);
      if (!mounted || request != _request) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _notOwner = _isForbidden(error);
        _error = _notOwner
            ? null
            : 'Could not load application access. Try again.';
      });
    }
  }

  Future<void> _share() async {
    final options = _options;
    if (options == null || _working || widget.busy) return;
    final candidates = options.apps
        .where((app) => !app.enrolled && !options.appIds.contains(app.appId))
        .toList(growable: false);
    if (candidates.isEmpty) return;

    final request = _request;
    final controller = widget.controller;
    final profileId = widget.id;
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
                  const Text(
                    'Before sharing',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(options.consentNotice),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: (value) =>
                        update(() => accepted = value == true),
                    title: const Text(
                      'I understand and authorize this sharing.',
                    ),
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
    if (choice == null || !mounted || request != _request) return;
    setState(() => _working = true);
    try {
      await controller.shareOwnProfile(
        profileId: profileId,
        destinationAppId: choice,
        consentVersion: options.consentVersion,
        revision: options.revision,
      );
      if (!mounted || request != _request) return;
      _options = null;
      _working = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile shared with $choice')));
      widget.onChanged?.call();
      await _load();
    } catch (_) {
      if (mounted && request == _request) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not share the profile. Please check your app access and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _working = false);
    }
  }

  Future<void> _remove(String appId) async {
    if (_working || widget.busy) return;
    final request = _request;
    final controller = widget.controller;
    final profileId = widget.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $appId access?'),
        content: const Text(
          'This app will no longer have access to this Health Profile. '
          'Existing clinical records retained under legal requirements are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || request != _request) return;
    setState(() => _working = true);
    try {
      await controller.revokeOwnProfileApp(
        profileId: profileId,
        targetAppId: appId,
      );
      if (!mounted || request != _request) return;
      _options = null;
      _working = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed $appId access')));
      widget.onChanged?.call();
      await _load();
    } catch (_) {
      if (mounted && request == _request) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to remove application access. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notOwner) return const SizedBox.shrink();
    final current = widget.currentAppId.trim().toLowerCase();
    final enrolled = (_options?.appIds ?? <String>[]).toSet().toList()..sort();
    final eligible =
        _options?.apps
            .where((app) => !app.enrolled && !enrolled.contains(app.appId))
            .toList(growable: false) ??
        const <EligibleProfileApp>[];
    final disabled = _working || widget.busy || _loading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Application access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text('Choose which applications can access this profile.'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            const SizedBox(height: 8),
            for (final app in enrolled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apps_outlined),
                title: Text(app),
                subtitle: Text(
                  app == current ? 'Current application' : 'Enrolled',
                ),
                trailing: TextButton.icon(
                  onPressed: disabled || _options == null
                      ? null
                      : () => _remove(app),
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

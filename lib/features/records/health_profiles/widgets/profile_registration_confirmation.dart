import 'package:material_ui/material_ui.dart';
import '../profiles_service.dart';

/// Deliberate staff attestation; exact notice and action authority come from backend.
Future<Map<String, Object?>?> confirmProfileRegistration(
  BuildContext context,
  ProfilesService service,
  String permission,
) async {
  final policy = await service.registrationPolicy();
  if (!context.mounted || !service.isCurrent()) return null;
  if (!(policy['effective_permissions'] as List? ?? []).contains(permission)) {
    throw StateError('Profile registration permission required');
  }
  final notice = policy['notice'];
  final version = policy['notice_version'];
  if (notice is! String || version is! String) {
    throw StateError('Authorization notice unavailable');
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm patient authorization'),
      content: Text(notice),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Patient directly authorized this'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted || !service.isCurrent()) return null;
  return {'accepted': true, 'notice_version': version};
}

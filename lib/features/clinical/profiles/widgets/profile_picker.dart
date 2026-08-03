// lib/features/clinical/profiles/widgets/profile_picker.dart

import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:flutter/material.dart';

Future<Profile?> showProfilePickerScreen({
  required BuildContext context,
  String? contactId,
  bool forcePickerMode = false,
}) {
  final cleanedContactId = (contactId ?? '').trim();

  final scopeContactId = forcePickerMode || cleanedContactId.isEmpty
      ? null
      : cleanedContactId;

  final scoped = scopeContactId != null;

  return Navigator.of(context).push<Profile>(
    MaterialPageRoute<Profile>(
      builder: (_) => ProfilesScreen(
        contactId: scopeContactId,
        allowExplicitContactLink: !scoped,
        selectionMode: true,
        selectionTitle: scoped ? 'Select profile' : 'Select patient',
      ),
    ),
  );
}

class ProfilePickerCard extends StatelessWidget {
  const ProfilePickerCard({
    super.key,
    required this.selectedProfile,
    required this.busy,
    required this.onChanged,
    this.contactId,
    this.forcePickerMode = false,
    this.canChange = true,
  });

  final Profile? selectedProfile;
  final bool busy;
  final ValueChanged<Profile> onChanged;

  final String? contactId;
  final bool forcePickerMode;
  final bool canChange;

  bool get _isScoped {
    if (forcePickerMode) return false;
    return (contactId ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final patient = selectedProfile;
    final enabled = canChange && !busy;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => _pickProfile(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(
                  patient == null
                      ? Icons.person_search_outlined
                      : Icons.person_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: patient == null
                    ? _EmptyProfileSummary(scoped: _isScoped)
                    : _SelectedProfileSummary(patient: patient),
              ),
              if (canChange) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: enabled ? () => _pickProfile(context) : null,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          patient == null
                              ? Icons.person_search_outlined
                              : Icons.switch_account_outlined,
                        ),
                  label: Text(patient == null ? 'Select' : 'Change'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfile(BuildContext context) async {
    if (!canChange || busy) return;

    final picked = await showProfilePickerScreen(
      context: context,
      contactId: contactId,
      forcePickerMode: forcePickerMode,
    );

    if (picked == null || !context.mounted) return;

    onChanged(picked);
  }
}

class _EmptyProfileSummary extends StatelessWidget {
  const _EmptyProfileSummary({required this.scoped});

  final bool scoped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scoped ? 'Select patient profile' : 'Select patient',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          scoped
              ? 'Choose from your linked patient profiles.'
              : 'Choose the patient profile to continue.',
        ),
      ],
    );
  }
}

class _SelectedProfileSummary extends StatelessWidget {
  const _SelectedProfileSummary({required this.patient});

  final Profile patient;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      patient.profileId,
      if ((patient.dob ?? '').trim().isNotEmpty) 'DOB: ${patient.dob}',
      if ((patient.phone ?? '').trim().isNotEmpty) patient.phone!.trim(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          patient.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(details.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

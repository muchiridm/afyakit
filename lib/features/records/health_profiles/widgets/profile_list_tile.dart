import 'package:flutter/material.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'profile_labels.dart';

class ProfileListTile extends StatelessWidget {
  const ProfileListTile({
    super.key,
    required this.profile,
    required this.selectionMode,
    required this.onTap,
  });

  final Profile profile;
  final bool selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final subtitleParts = <String>[];

    if (profile.relationship != null) {
      subtitleParts.add(ProfilesLabels.relationship(profile.relationship!));
    }

    final age = _profileAge(profile.dob);

    if (age != null) {
      subtitleParts.add('$age years');
    }

    final dob = _formatDob(profile.dob);

    if (dob != null) {
      subtitleParts.add('DOB $dob');
    }

    final contactName = (profile.contactDisplayName ?? '').trim();

    if (contactName.isNotEmpty) {
      subtitleParts.add(contactName);
    }

    final phone = (profile.phone ?? '').trim();

    if (phone.isNotEmpty) {
      subtitleParts.add(phone);
    }

    if (!profile.isActive) {
      subtitleParts.add('Inactive');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(_initials(profile.fullName))),
        title: Text(
          profile.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitleParts.isEmpty ? profile.profileId : subtitleParts.join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          selectionMode
              ? Icons.check_circle_outline
              : Icons.chevron_right_rounded,
          color: selectionMode ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

int? _profileAge(String? rawDob) {
  final dob = _parseDob(rawDob);

  if (dob == null) {
    return null;
  }

  final today = DateTime.now();

  var age = today.year - dob.year;

  final birthdayPassed =
      today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);

  if (!birthdayPassed) {
    age--;
  }

  return age >= 0 ? age : null;
}

String? _formatDob(String? rawDob) {
  final dob = _parseDob(rawDob);

  if (dob == null) {
    return null;
  }

  final day = dob.day.toString().padLeft(2, '0');

  final month = dob.month.toString().padLeft(2, '0');

  return '$day/$month/${dob.year}';
}

DateTime? _parseDob(String? rawDob) {
  final value = rawDob?.trim();

  if (value == null || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

// lib/core/home/activities/shared/activity_time_format.dart

String activityTimestampLabel({
  required DateTime date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final hasUpdate = _hasMeaningfulUpdate(
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  final label = hasUpdate ? 'Updated' : 'Created';

  return '$label: ${formatActivityDateTime(date)}';
}

String activityDateLabel({required String label, required DateTime date}) {
  return '$label: ${formatActivityDateTime(date)}';
}

String formatActivityDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = _monthName(local.month);
  final year = local.year.toString();

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day $month $year, $hour:$minute';
}

bool _hasMeaningfulUpdate({
  required DateTime? createdAt,
  required DateTime? updatedAt,
}) {
  if (updatedAt == null) return false;
  if (createdAt == null) return true;

  return updatedAt.difference(createdAt).abs().inSeconds > 5;
}

String _monthName(int month) {
  return switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => '',
  };
}

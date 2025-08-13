String formatDate(DateTime? dt) {
  if (dt == null) return '-'; // 🛑 Safe fallback for null dates
  final local =
      dt.toLocal(); // ✅ Converts UTC → local (e.g. EAT if device is set correctly)
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

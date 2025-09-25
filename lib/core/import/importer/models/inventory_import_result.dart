class InventoryImportResult {
  final bool ok;
  final Map<String, int>? counts; // e.g. { "medication": 123 }
  final List<String>? errors; // zod issues formatted by the backend
  final String? message; // generic message on 400s

  const InventoryImportResult({
    required this.ok,
    this.counts,
    this.errors,
    this.message,
  });

  factory InventoryImportResult.fromJson(Map<String, dynamic> json) {
    return InventoryImportResult(
      ok: json['ok'] == true,
      counts: (json['counts'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList(),
      message: json['message']?.toString(),
    );
  }

  static InventoryImportResult error(String msg) =>
      InventoryImportResult(ok: false, message: msg);
}

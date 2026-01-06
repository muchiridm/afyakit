List<String> batchRecordValidator(Map<String, dynamic> data) {
  final errors = <String>[];

  // 🔤 String Field Validator
  String? stringField(String key, {bool required = false}) {
    final value = data[key];
    if (value == null || (value is String && value.trim().isEmpty)) {
      if (required) errors.add('$key is required.');
      return null;
    }
    if (value is! String) {
      errors.add('$key must be a string.');
      return null;
    }
    return value.trim();
  }

  // 🔢 Integer Field Validator
  int? intField(String key, {bool required = false}) {
    final value = data[key];
    if (value == null) {
      if (required) errors.add('$key is required.');
      return null;
    }
    if (value is! int || value <= 0) {
      errors.add('$key must be a positive integer.');
      return null;
    }
    return value;
  }

  // 📆 Date Field Validator
  DateTime? dateField(String key, {bool required = false}) {
    final value = data[key];
    if (value == null) {
      if (required) errors.add('$key is required.');
      return null;
    }
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    errors.add('$key must be a valid date (DateTime or ISO8601 string).');
    return null;
  }

  // 📝 Only require editReason if isEdited is true
  if (data['isEdited'] == true) {
    stringField('editReason', required: true);
  }

  // ✅ Mandatory fields
  stringField('itemId', required: true);
  stringField('itemType', required: true);
  stringField('storeId', required: true);
  intField('quantity', required: true);
  dateField('receivedDate', required: true);
  dateField('expiryDate'); // Optional

  // 📦 Now required
  stringField('source', required: true); // ✅ Enforced here

  // 🧪 Optional metadata
  stringField('deliveryId');
  stringField('enteredBy');

  return errors;
}

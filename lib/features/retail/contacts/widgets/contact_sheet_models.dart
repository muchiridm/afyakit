// lib/features/retail/contacts/widgets/contact_sheet_models.dart

import '../models/zoho_contact.dart';

sealed class ContactSheetResult {
  const ContactSheetResult();

  factory ContactSheetResult.saveRequested(ZohoContact draft) = _SaveRequested;
  factory ContactSheetResult.deleteRequested(String contactId) =
      _DeleteRequested;
}

class _SaveRequested extends ContactSheetResult {
  const _SaveRequested(this.draft);
  final ZohoContact draft;
}

class _DeleteRequested extends ContactSheetResult {
  const _DeleteRequested(this.contactId);
  final String contactId;
}

extension ContactSheetResultX on ContactSheetResult {
  T when<T>({
    required T Function(ZohoContact draft) saveRequested,
    required T Function(String contactId) deleteRequested,
  }) {
    final self = this;
    if (self is _SaveRequested) return saveRequested(self.draft);
    if (self is _DeleteRequested) return deleteRequested(self.contactId);
    throw StateError('Unhandled ContactSheetResult: $runtimeType');
  }
}

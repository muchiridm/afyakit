sealed class ContactSheetResult {
  const ContactSheetResult();

  const factory ContactSheetResult.saveRequested(Map<String, Object?> draft) =
      ContactSaveRequested;
  const factory ContactSheetResult.deleteRequested(String nativeContactId) =
      ContactRemoveRequested;
}

final class ContactSaveRequested extends ContactSheetResult {
  const ContactSaveRequested(this.draft);
  final Map<String, Object?> draft;
}

final class ContactRemoveRequested extends ContactSheetResult {
  const ContactRemoveRequested(this.nativeContactId);
  final String nativeContactId;
}

extension ContactSheetResultX on ContactSheetResult {
  T when<T>({
    required T Function(Map<String, Object?> draft) saveRequested,
    required T Function(String nativeContactId) deleteRequested,
  }) => switch (this) {
    ContactSaveRequested(:final draft) => saveRequested(draft),
    ContactRemoveRequested(:final nativeContactId) => deleteRequested(
      nativeContactId,
    ),
  };
}

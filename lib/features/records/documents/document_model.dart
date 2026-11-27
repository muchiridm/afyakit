// Canonical Documents API v2.
enum DocumentType {
  identityDocument('identity_document', 'Identity document'),
  claimForm('claim_form', 'Claim form'),
  membershipCard('membership_card', 'Membership card'),
  authorization('authorization', 'Authorization'),
  prescription('prescription', 'Prescription'),
  labResult('lab_result', 'Laboratory result'),
  testReport('test_report', 'Test report'),
  medicalReport('medical_report', 'Medical report'),
  dischargeSummary('discharge_summary', 'Discharge summary'),
  referralLetter('referral_letter', 'Referral letter'),
  fitnessCertificate('fitness_certificate', 'Fitness certificate'),
  consentForm('consent_form', 'Consent form'),
  supportingDocument('supporting_document', 'Supporting document'),
  other('other', 'Other');

  const DocumentType(this.wire, this.label);
  final String wire;
  final String label;
  static DocumentType fromWire(Object? value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => throw const FormatException('Unknown document type'),
  );
}

enum DocumentStatus {
  uploaded('Uploaded'),
  verified('Verified'),
  rejected('Rejected'),
  archived('Archived');

  const DocumentStatus(this.label);
  final String label;
  String get wire => name;
  static DocumentStatus fromWire(Object? value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => throw const FormatException('Unknown document status'),
  );
}

enum DocumentVisibility {
  staffOnly('staff_only', 'Staff only'),
  profileMember('profile_member', 'Profile member');

  const DocumentVisibility(this.wire, this.label);
  final String wire;
  final String label;
  static DocumentVisibility fromWire(Object? value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => throw const FormatException('Unknown document visibility'),
  );
}

class Document {
  const Document({
    this.allowedActions = const [],
    required this.schemaVersion,
    required this.tenantId,
    required this.appId,
    required this.documentId,
    required this.profileId,
    required this.documentType,
    required this.fileName,
    required this.storagePath,
    required this.storageGeneration,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
    required this.visibility,
    required this.status,
    required this.isActive,
    required this.uploadedByUid,
    required this.updatedByUid,
    this.title,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });
  final List<String> allowedActions;
  bool can(String action) => allowedActions.contains(action);
  final int schemaVersion;
  final String tenantId,
      appId,
      documentId,
      profileId,
      fileName,
      storagePath,
      storageGeneration,
      contentType,
      sha256,
      uploadedByUid,
      updatedByUid;
  final DocumentType documentType;
  final DocumentVisibility visibility;
  final DocumentStatus status;
  final int sizeBytes;
  final bool isActive;
  final String? title, notes;
  final DateTime? createdAt, updatedAt;
  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title! : fileName;

  factory Document.fromJson(Map<String, Object?> json) {
    if (json['schema_version'] != 2) {
      throw const FormatException('Unsupported document schema');
    }
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Invalid document field: $key');
      }
      return value;
    }

    DateTime? date(String key) {
      final value = json[key];
      return value == null ? null : DateTime.parse(value as String);
    }

    return Document(
      allowedActions: (json['allowed_actions'] as List? ?? [])
          .whereType<String>()
          .toList(),
      schemaVersion: 2,
      tenantId: requiredText('tenant_id'),
      appId: requiredText('app_id'),
      documentId: requiredText('document_id'),
      profileId: requiredText('profile_id'),
      documentType: DocumentType.fromWire(json['document_type']),
      fileName: requiredText('file_name'),
      storagePath: requiredText('storage_path'),
      storageGeneration: requiredText('storage_generation'),
      contentType: requiredText('content_type'),
      sizeBytes: json['size_bytes'] as int,
      sha256: requiredText('sha256'),
      visibility: DocumentVisibility.fromWire(json['visibility']),
      status: DocumentStatus.fromWire(json['status']),
      isActive: json['is_active'] as bool,
      uploadedByUid: requiredText('uploaded_by_uid'),
      updatedByUid: requiredText('updated_by_uid'),
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
    );
  }
}

class DocumentCreateInput {
  const DocumentCreateInput({
    required this.documentId,
    required this.documentType,
    this.title,
    this.notes,
    this.visibility,
  });
  final String documentId;
  final DocumentType documentType;
  final String? title, notes;
  final DocumentVisibility? visibility;
  Map<String, Object?> toJson() => {
    'document_id': documentId,
    'document_type': documentType.wire,
    if (title != null) 'title': title,
    if (notes != null) 'notes': notes,
    if (visibility != null) 'visibility': visibility!.wire,
  };
}

/// Explicit flags distinguish clearing optional text from leaving it unchanged.
class DocumentUpdateInput {
  const DocumentUpdateInput({
    this.documentType,
    this.title,
    this.notes,
    this.clearTitle = false,
    this.clearNotes = false,
    this.visibility,
    this.status,
  });
  final DocumentType? documentType;
  final String? title, notes;
  final bool clearTitle, clearNotes;
  final DocumentVisibility? visibility;
  final DocumentStatus? status;
  Map<String, Object?> toJson() {
    if (status == DocumentStatus.archived) {
      throw ArgumentError('Use archive instead');
    }
    return {
      if (documentType != null) 'document_type': documentType!.wire,
      if (clearTitle || title != null) 'title': clearTitle ? null : title,
      if (clearNotes || notes != null) 'notes': clearNotes ? null : notes,
      if (visibility != null) 'visibility': visibility!.wire,
      if (status != null) 'status': status!.wire,
    };
  }
}

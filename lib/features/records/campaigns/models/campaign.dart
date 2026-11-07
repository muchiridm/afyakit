/// App-scoped campaigns: shared by Occuwell and Afya Tracker.
class Campaign {
  const Campaign({required this.id, required this.name, required this.examType,
    required this.status, this.organisationId, this.location, this.publicLinkEnabled = false,
    this.publicToken, this.questionnaireAssignments = const []});

  final String id;
  final String name;
  final String examType;
  final String status;
  final String? organisationId;
  final String? location;
  final bool publicLinkEnabled;
  /// Returned only during opening/rotation; never persisted in app storage.
  final String? publicToken;
  final List<CampaignQuestionnaireAssignment> questionnaireAssignments;

  factory Campaign.fromJson(Map<String, Object?> json) => Campaign(
    id: json['campaign_id'] as String,
    name: json['name'] as String,
    examType: json['exam_type'] as String,
    status: json['status'] as String,
    organisationId: json['organisation_id'] as String?,
    location: json['location'] as String?,
    publicLinkEnabled: json['public_link_enabled'] == true,
    publicToken: json['public_token'] as String?,
    questionnaireAssignments: (json['questionnaire_assignments'] as List? ?? const [])
        .map((e) => CampaignQuestionnaireAssignment.fromJson(Map<String, Object?>.from(e as Map)))
        .toList(growable: false),
  );
}

class CampaignQuestionnaireAssignment {
  const CampaignQuestionnaireAssignment({required this.templateId, required this.version,
    this.required = true, this.jobTitles = const []});
  final String templateId;
  final int version;
  final bool required;
  final List<String> jobTitles;

  factory CampaignQuestionnaireAssignment.fromJson(Map<String, Object?> json) =>
      CampaignQuestionnaireAssignment(
        templateId: json['template_id'] as String,
        version: json['version'] as int,
        required: json['required'] == true,
        jobTitles: (json['job_titles'] as List? ?? const []).cast<String>(),
      );

  Map<String, Object?> toJson() => {
    'template_id': templateId,
    'version': version,
    'required': required,
    'job_titles': jobTitles,
  };
}

class QuestionnaireTemplateSummary {
  const QuestionnaireTemplateSummary({required this.id, required this.title,
    required this.latestVersion});
  final String id;
  final String title;
  final int latestVersion;

  factory QuestionnaireTemplateSummary.fromJson(Map<String, Object?> json) =>
      QuestionnaireTemplateSummary(
        id: json['template_id'] as String,
        title: json['title'] as String,
        latestVersion: json['latest_version'] as int,
      );
}

class CampaignDraft {
  const CampaignDraft({required this.name, required this.examType,
    this.organisationId, this.location, this.questionnaire});
  final String name;
  final String examType;
  final String? organisationId;
  final String? location;
  final CampaignQuestionnaireAssignment? questionnaire;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'exam_type': examType,
    if (organisationId != null) 'organisation_id': organisationId,
    if (location != null && location!.trim().isNotEmpty) 'location': location!.trim(),
    'verification_mode': 'self_registration',
    if (questionnaire != null) 'questionnaire_assignments': [questionnaire!.toJson()],
  };
}

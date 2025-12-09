// Small value type used by IssueBatchService.resumeIssueIssuance(...)

class IssueResumeProgress {
  final int total;
  final int processed; // transit created or already existed (idempotent)
  final int missingBatch; // source batch not found
  final int insufficient; // source qty too low
  final int otherErrors;

  const IssueResumeProgress({
    required this.total,
    required this.processed,
    required this.missingBatch,
    required this.insufficient,
    required this.otherErrors,
  });

  IssueResumeProgress copyWith({
    int? total,
    int? processed,
    int? missingBatch,
    int? insufficient,
    int? otherErrors,
  }) {
    return IssueResumeProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      missingBatch: missingBatch ?? this.missingBatch,
      insufficient: insufficient ?? this.insufficient,
      otherErrors: otherErrors ?? this.otherErrors,
    );
  }

  @override
  String toString() =>
      'processed=$processed/$total, missingBatch=$missingBatch, '
      'insufficient=$insufficient, otherErrors=$otherErrors';
}

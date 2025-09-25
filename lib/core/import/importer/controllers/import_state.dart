class ImportState {
  final bool isLoading;
  final String? fileName;
  final int? validatedCount;

  // mapping support
  final List<String> pendingUnmappedGroups; // from dry-run (if available)
  final Map<String, String> pendingGroupMap; // fileGroup → canonical

  const ImportState({
    this.isLoading = false,
    this.fileName,
    this.validatedCount,
    this.pendingUnmappedGroups = const [],
    this.pendingGroupMap = const {},
  });

  ImportState copyWith({
    bool? isLoading,
    String? fileName,
    int? validatedCount,
    List<String>? pendingUnmappedGroups,
    Map<String, String>? pendingGroupMap,
  }) => ImportState(
    isLoading: isLoading ?? this.isLoading,
    fileName: fileName ?? this.fileName,
    validatedCount: validatedCount ?? this.validatedCount,
    pendingUnmappedGroups: pendingUnmappedGroups ?? this.pendingUnmappedGroups,
    pendingGroupMap: pendingGroupMap ?? this.pendingGroupMap,
  );

  static const empty = ImportState();
}

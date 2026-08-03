// lib/core/workspace/providers/workspace_mode_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WorkspaceMode { member, staff }

final workspaceModeProvider = StateProvider<WorkspaceMode>(
  (Ref ref) => WorkspaceMode.member,
);

final isMemberWorkspaceActiveProvider = Provider<bool>((Ref ref) {
  return ref.watch(workspaceModeProvider) == WorkspaceMode.member;
});

final isStaffWorkspaceActiveProvider = Provider<bool>((Ref ref) {
  return ref.watch(workspaceModeProvider) == WorkspaceMode.staff;
});

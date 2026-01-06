// lib/shared/providers/home_view_mode_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeViewMode { member, staff }

final homeViewModeProvider = StateProvider<HomeViewMode>((ref) {
  return HomeViewMode.member;
});

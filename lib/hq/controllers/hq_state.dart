import 'package:flutter/foundation.dart';

@immutable
class HqState {
  final int tabIndex; // 0: Tenants, 1: Users, 2: Superadmins
  final String userSearch; // mirrors allUsersSearchProvider
  final bool busy; // global busy overlay
  final String? banner; // ephemeral snackbar message

  const HqState({
    this.tabIndex = 0,
    this.userSearch = '',
    this.busy = false,
    this.banner,
  });

  HqState copyWith({
    int? tabIndex,
    String? userSearch,
    bool? busy,
    String? banner, // pass '' to clear
  }) {
    return HqState(
      tabIndex: tabIndex ?? this.tabIndex,
      userSearch: userSearch ?? this.userSearch,
      busy: busy ?? this.busy,
      banner: banner == '' ? null : (banner ?? this.banner),
    );
  }
}

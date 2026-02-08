import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';

/// Staff-only UI toggle: view the app as Staff UX or Member UX.
/// - Real user type remains staff; this is purely a UI preference.
/// - NOT autoDispose: must persist across navigation/rebuilds.
final staffViewModeProvider = StateProvider<EntryMode>((ref) {
  return EntryMode.staff;
});

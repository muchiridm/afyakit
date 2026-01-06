// lib/shared/home/providers/home_mode_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/home/models/home_mode.dart';

/// Controls whether the signed-in staff user is currently viewing
/// the app as Staff or Member (when member UX exists).
final homeModeProvider = StateProvider<HomeMode>((ref) => HomeMode.staff);

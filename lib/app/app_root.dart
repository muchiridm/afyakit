// lib/app/app_root.dart

import 'package:flutter/widgets.dart';

import 'package:afyakit/app/shells/app_afyakit.dart';
import 'package:afyakit/app/shells/app_hq.dart';
import 'package:afyakit/app/app_identity.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, this.mode});

  /// Optional explicit override, mainly useful for tests.
  ///
  /// Normal application startup should allow AppIdentity to resolve the mode
  /// from --dart-define=APP=...
  final AppMode? mode;

  @override
  Widget build(BuildContext context) {
    final resolvedMode = mode ?? AppIdentity.mode;

    return switch (resolvedMode) {
      AppMode.hq => const AppHq(),
      AppMode.tenant => const AppAfyaKit(),
    };
  }
}

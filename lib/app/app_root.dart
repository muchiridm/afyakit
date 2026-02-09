// lib/app/app_root.dart

import 'package:flutter/widgets.dart';

import 'package:afyakit/app/app_mode.dart';
import 'package:afyakit/app/app_afyakit.dart';
import 'package:afyakit/app/app_hq.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) => switch (mode) {
    AppMode.hq => const AppHq(),
    AppMode.tenant => const AppAfyaKit(),
  };
}

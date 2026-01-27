// lib/app/app_root.dart

import 'package:flutter/widgets.dart';

import 'package:afyakit/core/app/app_mode.dart';
import 'package:afyakit/core/app/app_afyakit.dart';
import 'package:afyakit/core/app/app_hq.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AppMode.hq:
        return const AppHq();
      case AppMode.tenant:
        return const AppAfyaKit();
    }
  }
}

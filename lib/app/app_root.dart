// lib/app/app_root.dart

import 'package:flutter/widgets.dart';

import 'package:afyakit/app/app_mode.dart';
import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/app/hq_app.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AppMode.hq:
        return const HqApp();
      case AppMode.tenant:
        return const AfyaKitApp();
    }
  }
}

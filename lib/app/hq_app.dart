// lib/app/hq_app.dart

import 'package:flutter/material.dart';

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import '../features/hq/base/auth/hq_gate.dart';

class HqApp extends StatelessWidget {
  const HqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afyakit HQ',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
      home: const HqGate(),
    );
  }
}

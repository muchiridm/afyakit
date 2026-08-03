// lib/app/app_hq.dart

import 'package:flutter/material.dart';

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import '../core/hq/shell/hq_gate.dart';

class AppHq extends StatelessWidget {
  const AppHq({super.key});

  static const String _title = 'AfyaKit HQ';
  static const Color _seedColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Title(
          title: _title,
          color: _seedColor,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const HqGate(),
    );
  }
}

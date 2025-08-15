import 'package:afyakit/shared/screens/home_screen/home_action_buttons.dart';
import 'package:afyakit/shared/screens/home_screen/home_header.dart';
import 'package:afyakit/shared/screens/home_screen/latest_activity_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/users/providers/current_user_provider.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final session = ref.watch(deliverySessionControllerProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('❌ Failed to load user'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('⚠️ User profile is missing')),
          );
        }

        ref.read(deliverySessionControllerProvider.notifier);

        return BaseScreen(
          scrollable: true,
          maxContentWidth: 800,
          header: HomeHeader(session: session),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              LatestActivityPanel(),
              SizedBox(height: 32),
              HomeActionButtons(),
            ],
          ),
        );
      },
    );
  }
}

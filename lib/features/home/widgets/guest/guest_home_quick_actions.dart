import 'package:material_ui/material_ui.dart';

import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_quick_action_button.dart';

class GuestHomeQuickActions extends StatelessWidget {
  const GuestHomeQuickActions({super.key, required this.onAuth});

  final VoidCallback onAuth;

  @override
  Widget build(BuildContext context) {
    return HomeQuickActionButton(
      actions: [
        HomeQuickAction(
          label: 'Log in / Sign up',
          icon: Icons.login_rounded,
          onPressed: onAuth,
        ),
      ],
    );
  }
}

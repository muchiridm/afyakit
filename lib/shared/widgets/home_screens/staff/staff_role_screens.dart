// lib/shared/widgets/home_screens/staff/staff_role_screens.dart

import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:flutter/material.dart';

class OwnerAdminHomeSection extends StatelessWidget {
  const OwnerAdminHomeSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Owner / Admin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Tenant settings'),
        const Text('• Staff & roles'),
        const Text('• Reports & analytics'),
        const Text('• Billing / invoices'),
      ],
    );
  }
}

class ManagerHomeSection extends StatelessWidget {
  const ManagerHomeSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manager', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Orders & approvals'),
        const Text('• Stock issues / transfers'),
        const Text('• Staff tasks'),
      ],
    );
  }
}

class PharmacistHomeSection extends StatelessWidget {
  const PharmacistHomeSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pharmacist', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Pending prescriptions'),
        const Text('• Dispensing queue'),
        const Text('• Clinical chat'),
      ],
    );
  }
}

class PrescriberHomeSection extends StatelessWidget {
  const PrescriberHomeSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Doctor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Consults / telemedicine'),
        const Text('• RX history'),
        const Text('• Follow-up list'),
      ],
    );
  }
}

class GenericStaffHomeSection extends StatelessWidget {
  const GenericStaffHomeSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Staff', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Recent activity'),
        const Text('• Tasks'),
      ],
    );
  }
}

class LogisticsHomeSection extends StatelessWidget {
  const LogisticsHomeSection({
    super.key,
    required this.user,
    required this.role,
  });

  final AuthUser user;
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    final title = switch (role) {
      StaffRole.runner => 'Runner',
      StaffRole.dispatcher => 'Dispatcher',
      _ => 'Logistics',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Deliveries / pickups'),
        const Text('• Supply runs'),
      ],
    );
  }
}

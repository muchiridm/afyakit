// lib/features/delivery_addresses/services/delivery_navigation_launcher.dart

import 'package:url_launcher/url_launcher.dart';

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';

class DeliveryNavigationLauncher {
  Future<void> navigateTo(DeliveryAddress address) async {
    final pin = address.pinLocation;
    if (pin == null) {
      throw StateError('No pin location available for this address.');
    }

    final lat = pin.latitude;
    final lng = pin.longitude;

    final googleDirections = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(googleDirections)) {
      final launched = await launchUrl(
        googleDirections,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }

    final fallbackSearch = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final launched = await launchUrl(
      fallbackSearch,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw StateError('Could not open a maps application.');
    }
  }

  Future<void> openInWaze(DeliveryAddress address) async {
    final pin = address.pinLocation;
    if (pin == null) {
      throw StateError('No pin location available for this address.');
    }

    final lat = pin.latitude;
    final lng = pin.longitude;

    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      throw StateError('Could not open Waze.');
    }
  }

  Future<void> openInAppleMaps(DeliveryAddress address) async {
    final pin = address.pinLocation;
    if (pin == null) {
      throw StateError('No pin location available for this address.');
    }

    final lat = pin.latitude;
    final lng = pin.longitude;

    final uri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      throw StateError('Could not open Apple Maps.');
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';

/// Compatibility name for the document services; same reactive app identity.
final documentAppIdProvider = Provider<String>(
  (ref) => ref.watch(appIdProvider),
);

// 📁 shared/providers/inventory_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

final inventorySearchQueryProvider = StateProvider<String>((ref) => '');
final inventorySortAscendingProvider = StateProvider<bool>((ref) => true);

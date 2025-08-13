import 'package:uuid/uuid.dart';

class IdGenerator {
  static final _uuid = Uuid();

  /// 🔑 Generate a unique user ID (e.g. for invited users)
  static String userId() => _uuid.v4();

  /// 📦 Generate a unique batch ID
  static String batchId() => _uuid.v4();

  /// 🏪 Generate a unique location ID
  static String locationId() => _uuid.v4();

  /// 🛠 Add more generators as needed
}

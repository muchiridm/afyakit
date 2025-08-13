class EmailHelper {
  static String normalize(String input) => input.trim().toLowerCase();

  static bool isValid(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email.trim().toLowerCase());
  }
}

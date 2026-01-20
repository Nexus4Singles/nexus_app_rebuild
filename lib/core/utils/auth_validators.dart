class AuthValidators {
  /// Username requirements:
  /// - required
  /// - allow spaces
  /// - must have each word start with capital letter
  /// - no minimum length required beyond non-empty
  static String? username(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';

    // Allow letters + spaces only
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(value)) {
      return 'Username can only contain letters and spaces';
    }

    // Ensure each word is Title Case: "Ayomide Bajomo"
    final words = value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    for (final w in words) {
      if (w.isEmpty) continue;
      if (w[0] != w[0].toUpperCase()) {
        return 'Each word must start with a capital letter';
      }
    }

    return null;
  }

  /// Password requirements:
  /// - min 8 chars
  /// - contains at least 1 letter
  /// - contains at least 1 number
  /// - contains at least 1 special character
  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]',
    ).hasMatch(value);

    if (!hasLetter || !hasNumber || !hasSpecial) {
      return 'Password must contain letters, numbers & a special character';
    }

    return null;
  }
}

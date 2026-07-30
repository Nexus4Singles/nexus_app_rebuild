class AuthValidators {
  /// Username requirements:
  /// - required
  /// - must be 3-12 characters
  /// - alphabet-only (letters only, no numbers/symbols/spaces)
  static String? username(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (value.length > 12) return 'Username must be 12 characters or fewer';

    if (!RegExp(r'^[A-Za-z]+$').hasMatch(value)) {
      return 'Username can only contain letters';
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

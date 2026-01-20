class TextFormatters {
  /// Converts a string into Title Case (each word capitalized).
  /// - Allows multiple spaces
  /// - Keeps apostrophes & hyphens inside words
  static String toTitleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final words = trimmed.split(RegExp(r'\s+'));
    final out =
        words.map((w) {
          if (w.isEmpty) return w;
          final lower = w.toLowerCase();

          // Handle hyphenated words: e.g. "john-doe" => "John-Doe"
          final parts = lower.split('-');
          final fixedParts =
              parts.map((p) {
                if (p.isEmpty) return p;
                return p[0].toUpperCase() + p.substring(1);
              }).toList();

          return fixedParts.join('-');
        }).toList();

    return out.join(' ');
  }
}

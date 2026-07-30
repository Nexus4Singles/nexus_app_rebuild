List<String> extractAdminReviewAudioUrls(Map<String, dynamic> data) {
  final dating = _asMap(data['dating']);
  final reviewPack = _asMap(dating?['reviewPack']);

  final urls = <String>[];
  void addAll(dynamic value) {
    if (value is! List) return;
    for (final item in value) {
      final text = item?.toString().trim();
      if (text != null && text.isNotEmpty) {
        urls.add(text);
      }
    }
  }

  addAll(reviewPack?['audioUrls']);
  addAll(dating?['audioPrompts']);
  addAll(data['audioPrompts']);

  final seen = <String>{};
  return urls.where((url) => seen.add(url.trim())).toList();
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

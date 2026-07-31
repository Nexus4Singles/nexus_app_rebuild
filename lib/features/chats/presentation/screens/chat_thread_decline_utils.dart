String buildDeclineButtonLabel() => 'Decline';

String buildDeclineNotificationBody(String? declinerName, String reason) {
  final name = (declinerName ?? '').trim();
  final userLabel = name.isNotEmpty ? '@$name' : 'Someone';
  final normalized = reason.trim().toLowerCase();

  if (normalized.contains('different connections')) {
    return '$userLabel is looking for a different type of connection at this time';
  }

  if (normalized.contains('good fit')) {
    return '$userLabel doesn\'t think they are a good fit for you';
  }

  if (normalized.contains('already chatting')) {
    return '$userLabel is occupied with someone else at the moment';
  }

  return '$userLabel declined politely';
}

String buildDeclineStatusText(String? reason) {
  final normalized = (reason ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Polite response sent';
  }
  return 'Response sent';
}

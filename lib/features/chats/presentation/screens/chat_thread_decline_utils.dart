class DeclineTarget {
  final String? messageId;
  final String? senderId;

  const DeclineTarget({this.messageId, this.senderId});
}

String buildDeclineButtonLabel() => 'Decline';

DeclineTarget? findLatestIncomingDeclineTarget<T>({
  required List<T> items,
  required bool Function(T item) isMe,
  required bool Function(T item) isDeclined,
  required String? Function(T item) messageId,
  required String? Function(T item) senderId,
}) {
  for (final item in items) {
    if (!isMe(item) && !isDeclined(item)) {
      return DeclineTarget(
        messageId: messageId(item),
        senderId: senderId(item),
      );
    }
  }
  return null;
}

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

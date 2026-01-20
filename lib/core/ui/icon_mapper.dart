import 'package:flutter/material.dart';

/// Maps strict icon keys to Material icons.
/// Unknown keys fall back to sparkles.
IconData iconFromKey(String key) {
  switch (key) {
    case 'flame':
      return Icons.local_fire_department_outlined;

    case 'check':
    case 'check-circle':
    case 'badge-check':
      return Icons.check_circle_outline;

    case 'lock':
      return Icons.lock_outline;

    case 'message-circle':
    case 'message-square':
      return Icons.chat_bubble_outline;

    case 'heart':
    case 'heart-handshake':
      return Icons.favorite_border;

    case 'shield':
    case 'shield-check':
      return Icons.verified_user_outlined;

    case 'calendar-check':
    case 'calendar':
      return Icons.calendar_month_outlined;

    case 'users':
      return Icons.groups_outlined;

    case 'user':
      return Icons.person_outline;

    case 'wallet':
      return Icons.account_balance_wallet_outlined;

    case 'timer':
    case 'clock':
      return Icons.schedule_outlined;

    case 'trophy':
      return Icons.emoji_events_outlined;

    case 'flag':
      return Icons.flag_outlined;

    case 'target':
      return Icons.gps_fixed;

    case 'sparkles':
    default:
      return Icons.auto_awesome_outlined;
  }
}

import 'package:intl/intl.dart';

/// Date and time utility functions
class DateUtils {
  DateUtils._();

  /// Format date as "Jan 15, 2024"
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format date as "January 15, 2024"
  static String formatFullDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  /// Format time as "2:30 PM"
  static String formatTime(DateTime date) {
    return DateFormat.jm().format(date);
  }

  /// Format as "Jan 15, 2024 at 2:30 PM"
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }

  /// Format as relative time: "2 hours ago", "Yesterday", etc.
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return formatDate(date);
    }
  }

  /// Get week number of the year
  static int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get start of week (Monday)
  static DateTime startOfWeek(DateTime date) {
    final daysToSubtract = date.weekday - 1;
    return startOfDay(date.subtract(Duration(days: daysToSubtract)));
  }

  /// Format duration as "5 min" or "1 hr 30 min"
  static String formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    } else {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) {
        return '$hours hr';
      }
      return '$hours hr $mins min';
    }
  }
}

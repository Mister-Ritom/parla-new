import 'package:cloud_firestore/cloud_firestore.dart';

class TimeFormatter {
  static bool isInfinite(DateTime date) {
    return date.year >= 9999; // your infinite-expiration sentinel
  }

  static String timeAgo(DateTime date) {
    if (isInfinite(date)) return "never";

    final now = Timestamp.now().toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    if (diff.inDays < 30) return "${(diff.inDays / 7).floor()}w ago";
    if (diff.inDays < 365) return "${(diff.inDays / 30).floor()}mo ago";
    return "${(diff.inDays / 365).floor()}y ago";
  }

  static String timeUntil(DateTime date) {
    if (isInfinite(date)) return "Never";

    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) return timeAgo(date);

    if (diff.inSeconds < 60) return "in ${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "in ${diff.inMinutes}m";
    if (diff.inHours < 24) return "in ${diff.inHours}h";
    if (diff.inDays < 7) return "in ${diff.inDays}d";
    if (diff.inDays < 30) return "in ${(diff.inDays / 7).floor()}w";
    if (diff.inDays < 365) return "in ${(diff.inDays / 30).floor()}mo";
    return "in ${(diff.inDays / 365).floor()}y";
  }

  static String formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final day = date.day;
    final suffix = (day >= 11 && day <= 13)
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };

    return '$day$suffix ${months[date.month - 1]}';
  }
}

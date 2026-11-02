import 'package:intl/intl.dart';

class DateFormatter {
  static String formatShortDate(DateTime? dateTime) {
    if (dateTime == null) return 'No deadline';
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  static String formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

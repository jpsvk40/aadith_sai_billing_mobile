import 'package:intl/intl.dart';

class AppDateUtils {
  static final _displayFormatter = DateFormat('dd MMM yyyy');
  static final _displayWithTimeFormatter = DateFormat('dd MMM yyyy, hh:mm a');
  static final _apiFormatter = DateFormat('yyyy-MM-dd');
  static final _monthYearFormatter = DateFormat('MMM yyyy');

  static String formatDisplay(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      return _displayFormatter.format(dt.toLocal());
    } catch (_) {
      return '-';
    }
  }

  static String formatWithTime(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      return _displayWithTimeFormatter.format(dt.toLocal());
    } catch (_) {
      return '-';
    }
  }

  static String formatApi(DateTime date) => _apiFormatter.format(date);

  static String formatMonthYear(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      return _monthYearFormatter.format(dt.toLocal());
    } catch (_) {
      return '-';
    }
  }

  static String timeAgo(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inDays > 7) return formatDisplay(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '-';
    }
  }
}
